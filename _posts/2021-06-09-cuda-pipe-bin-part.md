---
layout: post
title:  "Cuda Binary Partitions and Pipelines"
date:   2021-06-09 17:26:11 -0500
categories: cuda
---

Something I have recently been working on is fusing two GPU kernels in PyFR, one
kernel is a pointwise kernel and the other is a matrix multiplication kernel.
For more background you can watch this [talk][talk]. Both these kernels are
memory bandwidth bound, and so to increase speed we can reduce going out to main
memory by using shared memory.

Some background on shared memory, it site at the same level as L1 cache, and
hence has much higher bandwidth, but the user can explicitly perform load and
store operations on it. However, to load something into shared from global, the
compiler will first load it from global into a register, and then from the
register to shared. The reason, at least as far as I can see, for doing this is
that shared memory is shared between threads in a block, and only after a thread
sync will it be guaranteed that the value will be resident in shared. Therefore,
putting it in a register would give the compiler more flexibility when
optimising. However, this doesn't necessarily fit with what an engineer might
want.

Enter the Ampere series of GPUs by Nvidia. The interesting thing that was
introduced with the Ampere was ability to bypass the register stage, and even L1
and L2 cache, when _loading_ global into shared. To achieve this you currently
have to make use of the `memcpy_async` functionality added in CUDA 11. There are
a couple way to use this but, at least to me, the way that is more interesting
are pipelines.

A pipeline is a feature exposed to Volta (`sm_70`) and later GPUs, and its a
queue that can have multiple stage. Producers add jobs to the tail of the queue
and consumers remove jobs from the head. As the names suggests, producers
'produce' data to be used by the consumers. Why might you want to do this? Well
Ampere has dedicated hardware to do the load into shared that bypasses
registers/cache. A simple example is shown below:

{% highlight c %}
__global__ example(int n, float* __restrict__ g)
{
    auto block = cg::this_thread_block();
    extern __shared__ float s[];
    constexpr size_t stages = 1;
    constexpr auto scope = cuda::thread_scope::thread_scope_block;
    __shared__ cuda::pipeline_shared_state<scope, stages> shared_state;
    auto pipe = cuda::make_pipeline(block, &shared_state);

    pipe.producer_aquire();
        cuda::memcpy_async(block, s + 2*block.thread_rank(), g + 2*block.thread_rank(), 2*sizeof(float), pipe);
    pipe.producer.commit();

    pipe.consumer_wait();
        //Some compute
    pipe.consmer_release();
}
{% endhighlight %}

This is a single stage pipeline, where each thread simply loads a two floats
from `g` into `s`. This works in chunks, so thread 0 will load `g[0]` and `g[1]`
into `s[0]` and `s[1]`, respectively. (This didn't seem to be obviously
documented at the time I wrote this).

You can use this feature on Volta but you don't get the hardware acceleration
that Ampere has. So for my application what I wanted to do was have some threads
working as producers and some as consumers, currently, all threads are both. To
achieve this it made the most sense to use the binary partition feature. We
start by defining the roles, for example like this:

{% highlight c %}
    auto role = ((block.thread_rank() % 2) == 0) ? cuda::pipeline_role::producer : cuda::pipeline_role::consumer;
{% endhighlight %}

This makes even threads producers and odd threads consumers. We can then pass
this when we make the pipeline to get what we want, for example:

{% highlight c %}
    auto pipe = cuda::make_pipeline(block, &shared_state, role);
{% endhighlight %}

Now if you make those modification to the simple `memcpy_async` example above it
will hang and the consumer wait. What is going on? Well there is nothing
currently stopping the threads that we want to be exclusively consumers
executing the provider part. According to the C++ API documentation on git, the
behaviour in this case is undefined. But looking at the source it seems that the
consumer threads get suck waiting on the copy that never happens.

Instead, you have to add some protection to the producer and consumer
statements. So the complete example would be:

{% highlight c %}
    auto block = cg::this_thread_block();
    extern __shared__ float s[];
    constexpr size_t stages = 1;
    constexpr auto scope = cuda::thread_scope::thread_scope_block;
    auto role = ((block.thread_rank() % 2) == 0) ? cuda::pipeline_role::producer : cuda::pipeline_role::consumer;
    __shared__ cuda::pipeline_shared_state<scope, stages> shared_state;
    auto pipe = cuda::make_pipeline(block, &shared_state, role);

    if(role == cuda::pipeline_role::producer)
    {
        pipe.producer_aquire();
            cuda::memcpy_async(block, s + 2*block.thread_rank(), g + 2*block.thread_rank(), 2*sizeof(float), pipe);
        pipe.producer.commit();
    }

    if(role == cuda::pipeline_rol::consumer)
    {
         pipe.consumer_wait();
            //Some compute
        pipe.consmer_release();
    }   
{% endhighlight %}

I thought I would add this clarification, mainly as it caused me some issues and
the feature seemed to be a bit under-documented. You might be wondering how this
performed in may application, well it seemed to lead to significant branch
divergence, that killed performance. It also seems to me that although the
`memcpy_async` is supported on Volta, you really don't get the benefits.
However, in my experience with A100s, it seems that the asynchronous paradigm
will prove to be quite important, but due to the dedicated hardware the
method I just described may not be that useful. More testing required.

[talk]: https://doi.org/10.52843/cassyni.2x9rkc