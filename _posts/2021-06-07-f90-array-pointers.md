---
layout: post
title:  "Array pointers in F90"
date:   2021-06-07 20:31:21 -0500
categories: fortran
---

I was recently playing around with pointers in fortran, what I wanted to 
acheive was an array of pointers where each pointed to a different elemnt 
in an array. In C/C++ this is simple to achieve, something a bit like this 
for example:

{% highlight c %}
	float a[2];
	float *b[2];

	a[0] = 1.; a[1] = 2.;
	b[0] = &a[1]; b[1] = &a[0];
{% endhighlight %}

However, this isn't natively supported in fortran at the moment. This is 
perhaps with good reason, in fortran by assuming that pointers to an array 
point to a contiguous part of the array it avoids alaising; meaning the 
compiler can make curtain assumptions. An example of a pointer in fortran 
would be: 

{% highlight fortran %}
	real, target :: a(10)
	real, pointer :: b(:)
	b => a(4:6)
{% endhighlight %}

To acheive the behaviour I'm interested, one method is to declare a derived 
type, and then make an array of that type. For example, to match the 
behavour of the earlier C/C++ example you could do:

{% highlight fortran %}
	type real_ptr
		real(kind=4), pointer :: p
	end type real_ptr 
	real(kind=4), target :: a(3)
	type(real_ptr) :: b(2)
	b(1)%p => a(2); b(2)%p => a(1)
{% endhighlight %}

You might rightly ask, how does this perform? Surely using a derived type 
and having to invoke a bit more heavy machinery can't be too performant.
Well below is the interesting part of the assembly:

{% highlight asm %}
	movss	xmm0, DWORD PTR .LC0[rip]
	movss	DWORD PTR [rbp-8], xmm0
	movss	xmm0, DWORD PTR .LC1[rip]
	movss	DWORD PTR [rbp-4], xmm0
	lea	rax, [rbp-8]
	add	rax, 4
	mov	QWORD PTR [rbp-32], rax
	lea	rax, [rbp-8]
	mov	QWORD PTR [rbp-24], rax
{% endhighlight %}

This was compiled with GCC 8.4.0 on an Intel based system. The interesting 
bit is that, barring some addtional standard setup bits required by fortran, 
the assembly is _exactly_ the same. So to answer the question, is this 
apporach performant in fortran; the answer is its as performant as C/C++ in 
this case.

I also tried this on an Arm based system, but the differences were more 
significant. But frankly I put this down to the fortran compiler for Arm. 