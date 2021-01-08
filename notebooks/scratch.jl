### A Pluto.jl notebook ###
# v0.12.18

using Markdown
using InteractiveUtils

# ╔═╡ 8b6135cb-32a9-4849-8fde-e6d8b49a4fc9
using PlutoUI

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

# ╔═╡ Cell order:
# ╟─b51b7e9b-df76-4e57-83e6-03f78e0b1482
# ╟─29033614-97ca-4b7f-b946-ebdb91edd088
# ╟─47d7e091-f3f1-482f-9597-9bfd34ec2233
# ╟─535b82b2-942d-4834-9a94-8d0ee8282b99
# ╟─8b6135cb-32a9-4849-8fde-e6d8b49a4fc9
