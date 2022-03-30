---
layout: post
title: "Dubiner Basis for Regular Tetrahedrons"
date: 2022-03-30 16:00:12 +0100
categories: polynomials
---

I have recently been working on extending stable flux reconstruction methods to
polygons and polyhedra. One of the difficulties in doing this is imposing the
symmetry conditions. This can be done, but is made much easier if a regular
reference element is used. However for tetrahedron, it is common to use an
irregular reference tetrahedron, specifically one with nodes:

$$
   [-1, -1, -1], \; [1, -1, -1],\; [-1,1,-1],\; [-1,-1,1]
$$

The basis set out in Hesthaven and Warburton (2008) uses these points, but as I
say this isn't very helpful for imposing rotational symmetries. Instead, I would
like to use the regular tetrahedron defined by the points:

$$
    [\sqrt{8/9}, 0, -1/3],\; [-\sqrt{2/9}, \sqrt{2/3}, -1/3],\; [-\sqrt{2/9},-\sqrt{2/3}, -1/3],\; [0,0,1]
$$

I couldn't find a reference that had considered a basis on these points before,
so as making the basis was a bit fiddly I decided to write it down for others. 

$$
   \phi_{i,j,k}(x,y,z) = \frac{2(c-1)^{i+j}(1-a)^j}{\sqrt{3}}J^{(0,0)}_{i}(a){J}^{(2i+1,0)}_j(b){J}^{(2i+2j+2,0)}_k(c)
$$

where $$J$$ are normalised Jacobi polynomials and for

$$
   a = -\frac{(4\sqrt{2}x + z - 1)}{3(z - 1)},\; b = -\frac{2\sqrt{3}y}{2x + \sqrt{2}(z - 1)},\; c = \frac{3z - 1}{2}.
$$

In the transformed coordinate system of $$a$$, $$b$$, and $$c$$, the domain is
$$[-1,1]^3$$. One disadvantage of this basis is that it isn't quite normalised
as I couldn't work that out. The normalisation is probably non-trivial due to
the $$x$$ and $$z$$ dependence in $$a$$ and $$b$$. However, this isn't such a
big issue as it just means you have to calculate the mass matrix explicitly.
Which is a trade-off I'm willing to make for the utility this basis offers.
