### A Pluto.jl notebook ###
# v0.12.18

using Markdown
using InteractiveUtils

# ╔═╡ 8b6135cb-32a9-4849-8fde-e6d8b49a4fc9
using PlutoUI, BenchmarkTools

# ╔═╡ b51b7e9b-df76-4e57-83e6-03f78e0b1482
TableOfContents()

# ╔═╡ 29033614-97ca-4b7f-b946-ebdb91edd088
md"""
# Let's talk about memory
"""

# ╔═╡ 47d7e091-f3f1-482f-9597-9bfd34ec2233
md"""
There is a disconnect between the theoretical CS world and the real world. For example:

	Linked lists are actually not the bee's knees

Why? Because hardware matters. Here is a mental model of the memory layout for a modern, multi-core computer:

![](https://hackernoon.com/hn-images/1*nT3RAGnOAWmKmvOBnizNtw.png)

The CPU lives at the bottom and directly accesses your computer's memory (like your RAM) through a series of caches, a smaller bit of fast memory for doing things like quick lookups if the CPU knows it will need to use a bit of data again soon. These lookups and accesses are a physical process that takes time though, so the "closer" the cache is to the CPU, the faste this process should be. So, generally, your L1 cache will have the fastest access and L3 will have the slowest.

Speaking of time, here's a [famous chart](http://ithare.com/infographics-operation-costs-in-cpu-clock-cycles/) summarizing how long various operations can take, compared to how far light could travel in that time!

Writing code to take advantage of how memory is accessed can then give us some serious performance improvements.
"""

# ╔═╡ 535b82b2-942d-4834-9a94-8d0ee8282b99
md"""
# An example with arrays
"""

# ╔═╡ 1dda8db4-a1ff-455e-a0b8-32f1b87e1fe6
md"""
We like to think of matrices in computer memory as being these 2D objects, but in reality they are just a 1D vector of memory addresses. When we use human notation like (i, j) indexing, what we are really doing is transforming something like this:
"""

# ╔═╡ 6373654f-6415-4a6a-b2f1-bf5b75dd7fbf
A_vec = 1:9

# ╔═╡ cc2e47e0-6235-426f-a880-4e11494b71f9
A_mat = reshape(A_vec, 3, 3)

# ╔═╡ 2b8792a7-9d56-461c-a4f3-35041ba0c270
A_mat[3, 2]

# ╔═╡ 438816f0-e8fd-4e3b-8107-fc696510a741
md"""
To this, under the hood:
"""

# ╔═╡ 072f4023-203c-405c-8795-6801e0fa5806
let
	i = 3
	j = 2
	A_vec[i + (j-1)*3]
end

# ╔═╡ 94b6c3e3-467e-46d5-b33c-f9974281db92
md"""
Using the convention for accessing these entries can then make a noticeable difference in performance. In Julia, arrays are column-major, so let's see what happens if we try looping through it (an example of accessing things in memory) in a row vs. column major fashion:
"""

# ╔═╡ 51bf3e61-4b8e-4c1b-95a1-7650e5aed151
A = rand(100, 100); B = rand(100, 100); C = rand(100, 100);

# ╔═╡ 49c03535-4160-42ad-8f2b-27f4b8e3afbd
function inner_rows!(C, A, B)
	for i in 1:100, j in 1:100
		C[i, j] = A[i, j] + B[i, j]
	end
end

# ╔═╡ 7714f2a7-4da4-4779-9ffc-7f19be16543e
function inner_cols!(C, A, B)
	for j in 1:100, i in 1:100
		C[i, j] = A[i, j] + B[i, j]
	end
end

# ╔═╡ 62b4b712-8468-4423-a65a-d6d9066fe378
with_terminal() do
	@btime inner_rows!($C, $A, $B)
	@btime inner_cols!($C, $A, $B)
end

# ╔═╡ c2ad7563-35d4-4a6d-838d-61be4443d567
md"""
We see a speed-up when we respect the memory layout of our data because the CPU does not need to skip around as much or break the heuristics it uses to guess which bits of data we might need ahead of time.
"""

# ╔═╡ Cell order:
# ╟─b51b7e9b-df76-4e57-83e6-03f78e0b1482
# ╟─29033614-97ca-4b7f-b946-ebdb91edd088
# ╟─47d7e091-f3f1-482f-9597-9bfd34ec2233
# ╟─535b82b2-942d-4834-9a94-8d0ee8282b99
# ╟─1dda8db4-a1ff-455e-a0b8-32f1b87e1fe6
# ╠═6373654f-6415-4a6a-b2f1-bf5b75dd7fbf
# ╠═cc2e47e0-6235-426f-a880-4e11494b71f9
# ╠═2b8792a7-9d56-461c-a4f3-35041ba0c270
# ╟─438816f0-e8fd-4e3b-8107-fc696510a741
# ╠═072f4023-203c-405c-8795-6801e0fa5806
# ╟─94b6c3e3-467e-46d5-b33c-f9974281db92
# ╠═51bf3e61-4b8e-4c1b-95a1-7650e5aed151
# ╠═49c03535-4160-42ad-8f2b-27f4b8e3afbd
# ╠═7714f2a7-4da4-4779-9ffc-7f19be16543e
# ╠═62b4b712-8468-4423-a65a-d6d9066fe378
# ╟─c2ad7563-35d4-4a6d-838d-61be4443d567
# ╟─8b6135cb-32a9-4849-8fde-e6d8b49a4fc9
