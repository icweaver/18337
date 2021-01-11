### A Pluto.jl notebook ###
# v0.12.18

using Markdown
using InteractiveUtils

# ╔═╡ 3509efff-7beb-4c51-9217-4e9a1f2618e0
using StaticArrays

# ╔═╡ f8357564-8cf5-4329-86da-ea182471e0c9
using Base.Threads

# ╔═╡ 0b809325-6ac4-4326-8e07-0b0324fd3a6d
using Statistics

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

# ╔═╡ 861210cf-10ee-4367-817b-f2fc446dd671
md"""
# Concurrency
"""

# ╔═╡ ca40e65a-ab7e-4fb9-a708-88ec8602eb42
with_terminal() do
	@time for i in 1:5
		sleep(2)
	end
end

# ╔═╡ 436cd061-93ea-45ec-a606-a09b2dd476f0
with_terminal() do
	@time @sync for i in 1:5
		@async sleep(2)
	end
end

# ╔═╡ c96d99bd-0d56-41dd-ac7a-57c5bffd9fc0
md"""
# Multi-threading
"""

# ╔═╡ a67cc8ad-d8ef-4830-8068-8aed7062377a
md"""
Let's start with a straightforward serial apprach to solving the Lorez equations first:
"""

# ╔═╡ f1c0022f-c12f-4c61-b6a0-61c2debe840d
# Put it on the heap
function lorenz!(du, u, p)
	α, σ, ρ, β = p
	@inbounds begin
		du[1] = u[1] + α*(σ*(u[2] - u[1]))
		du[2] = u[2] + α*(u[1]*(ρ - u[3] - u[2]))
		du[3] = u[3] + α*(u[1]*u[2] - β*u[3])
	end
end

# ╔═╡ c07e6957-a153-4bfa-a2a9-3ce6c4857922
function solve_system_save_iip!(u, f, u0, p, n)
	@inbounds u[1] = u0
	@inbounds for i in 1:length(u)-1
		f(u[i+1], u[i], p)
	end
	return u
end

# ╔═╡ 709e5550-c0dd-46bc-ac0d-77c83b648d22
u_vec = [Vector{Float64}(undef, 3) for i in 1:1_000]

# ╔═╡ bde73ff2-9fc3-4708-baed-03a9e56c8337
p = (0.02, 10.0, 28.0, 8/3)

# ╔═╡ 0c25ec5b-cb24-4c1e-80bd-3ba748119204
with_terminal() do
	@btime solve_system_save_iip!(u_vec, lorenz!, [1.0, 0.0, 0.0], p, 1_000)
end

# ╔═╡ 043baaf9-ffb5-4c26-be6c-40feaea960ea
md"""
Then SA
"""

# ╔═╡ 57d5c854-9f9c-4080-adda-c5484f9e449e
function lorenz(u, p)
	α, σ, ρ, β = p
	@inbounds begin
		du1 = u[1] + α*(σ*(u[2] - u[1]))
		du2 = u[2] + α*(u[1]*(ρ - u[3] - u[2]))
		du3 = u[3] + α*(u[1]*u[2] - β*u[3])
	end
	return @SVector [du1, du2, du3]
end

# ╔═╡ 23784b92-7280-4d56-a1f9-24a546383b72
function solve_system_save!(u, f, u0, p, n)
	@inbounds u[1] = u0
	@inbounds for i in 1:length(u)-1
		u[i+1] = f(u[i], p)
	end
	return u
end

# ╔═╡ 060d936d-c759-4064-9302-a454fa107bb7
u = Vector{typeof(@SVector([1.0, 0.0, 0.0]))}(undef, 1_000)

# ╔═╡ 1f27d62d-674a-4dfd-8912-2689515f17bc
with_terminal() do
	@btime solve_system_save!(u, lorenz, @SVector([1.0, 0.0, 0.0]), p, 1_000)
end

# ╔═╡ cea8ce9f-f657-44b9-b2ed-de3f3983ad08
md"""
Now let's try multithreaded. Shared memory, embarassingly parallel. Using heap approach from first example instead of SA example so that the data in each of our threads can talk to each other
"""

# ╔═╡ c2326f0b-356f-4353-b1e4-98960b4f4903
function lorenz_mt!(du, u, p)
	α, σ, ρ, β = p
	let du=du, u=u, p=p
		Threads.@threads for i in 1:3
			@inbounds begin
				if i == 1
					du[1] = u[1] + α*(σ*(u[2] - u[1]))
				elseif i == 2
					du[2] = u[2] + α*(u[1]*(ρ - u[3] - u[2]))
				else
					du[3] = u[3] + α*(u[1]*u[2] - β*u[3])
				end
			end
		end
	end
end

# ╔═╡ d386b7f7-a4e8-41b6-a8be-b26cc657db85
with_terminal() do
	@btime solve_system_save_iip!(u_vec, lorenz_mt!, [1.0, 0.0, 0.0], p, 1_000)
end

# ╔═╡ 757aa797-177e-4e45-8a27-2e857ba17e38
md"""
Oof, that's bad. By like three orders of magnitude. A major reason why goes back to the [famous chart](http://ithare.com/infographics-operation-costs-in-cpu-clock-cycles/). Creating threads is a relatively heavy CPU operation (Allocation+deallocation pair) compared to the handful of floating point operations ("Simple register-register op") we are doing per thread. In other words, mult-threading is completely overkill for this specific problem and is not worth the additional overhead incurred by just setting up the threads in the first place.

The moral of the story is that multi-threading is not a silver bullet. You need to know the nature of the problem to know which tools will work best to solve it. As a rule of thumb, if an op takes a couple hundred nanosecond or less, it's probably overkill to try and multithread it.

With that in mind, let's turn to a similar problem that is much more amenable to parallelization: Parameter Searches.
"""

# ╔═╡ 51e88fd0-e199-40fa-add1-a982db7bd27c
md"""
# Multithreaded Parameter Searches
"""

# ╔═╡ cdb8aac6-232d-470c-98aa-839d93fc20fc
const _u_cache = Vector{typeof(@SVector([1.0, 0.0, 0.0]))}(undef, 1_000)

# ╔═╡ 8596f5af-3696-4d22-a847-49b76ca6a373
function _compute_trajectory_mean(u, u0, p)
	solve_system_save!(u, lorenz, u0, p, 1_000)
	return mean(u)
end

# ╔═╡ 82543bf0-1b36-4511-8651-87d4492169cc
# Using a closure to keep the API uniform
compute_trajectory_mean(u0, p) = _compute_trajectory_mean(_u_cache, u0, p)

# ╔═╡ b2f35677-cf25-42e3-8fa6-124d0186d0a7
with_terminal() do
	@btime compute_trajectory_mean(@SVector([1.0, 0.0, 0.0]), p)
end

# ╔═╡ b77c5a71-e2d8-4a2d-bcd0-8c9000e21033
md"""
Looks good, now let's search different inputs for `p`:
"""

# ╔═╡ 7a3385b5-eb08-4625-8268-348a002132b7
ps = [(0.02, 10.0, 28.0, 8/3) .* (1.0, rand(3)...) for i in 1:1_000]

# ╔═╡ c948a3b4-0af1-44cb-8300-331baf343581
serial_out = map(
	p -> compute_trajectory_mean(@SVector([1.0, 0.0, 0.0]), p),
	ps
)

# ╔═╡ daa14169-be2b-4802-9e95-7b309935f4e5
md"""
Now multithreading:
"""

# ╔═╡ 1425adbd-6aab-4a41-85c3-95c85acf1bd0
function tmap(f, ps)
	out = Vector{typeof(@SVector([1.0, 0.0, 0.0]))}(undef, 1_000)
	Threads.@threads for i in 1:1_000
		out[i] = f(ps[i])
	end
	return out
end

# ╔═╡ 50a5f536-eeee-4053-8405-603c739bbf35
threaded_out = tmap(
	p -> compute_trajectory_mean(@SVector([1.0, 0.0, 0.0]), p),
	ps
)

# ╔═╡ c88c7ea8-b6c7-4a6c-af16-8d01ab8ebcf6
md"""
Let's compare to the serial output:
"""

# ╔═╡ 03db62b2-ff33-4e3c-9c6c-0943fbd9cc19
serial_out - threaded_out

# ╔═╡ e81bdefd-77e3-4b23-9ade-c9f8ee25535c
md"""
Oh no, they're not the same! The problem is our cache vector, `_u_cache`. In serial, this is fine, but in parallel the threads just keep overwritting each other because they are all sharing that single cache. The process is not **thread safe**. We can fix this by giving each thread its own cache:
"""

# ╔═╡ 746db25d-f176-42d8-bec7-b9c9e159d5c6
const _u_cache_threads = [
	Vector{typeof(@SVector([1.0, 0.0, 0.0]))}(undef, 1_000)
	for i in 1:Threads.nthreads()
]

# ╔═╡ 1c08555c-ba4d-405e-a7de-4f53656556e9
function compute_trajectory_mean_thread_safe(u0, p)
	solve_system_save!(_u_cache_threads[Threads.threadid()], lorenz, u0, p, 1_000)
	return mean(_u_cache_threads[Threads.threadid()])
end

# ╔═╡ 2fd4f919-9c75-4572-8562-879a31ad1c46
threaded_out_thread_safe = tmap(
	p -> compute_trajectory_mean_thread_safe(@SVector([1.0, 0.0, 0.0]), p),
	ps
)

# ╔═╡ 0e42e5c8-b690-45eb-be03-1a640020adc4
md"""
Let's check the output now:
"""

# ╔═╡ da4a3ad9-eb52-440e-bcb6-951faffc4cdc
threaded_out_thread_safe - serial_out

# ╔═╡ 81b08415-d45d-40c2-bfb7-ee82c6d10e09
md"""
Nice, we are getting the same results as the serial approach now! How fast is it?
"""

# ╔═╡ e586c612-bf08-4eaa-aa81-a50adc934017
with_terminal() do
	@btime map(
		p -> compute_trajectory_mean(@SVector([1.0, 0.0, 0.0]), p),
		$ps,
	)
	@btime tmap(
		p -> compute_trajectory_mean_thread_safe(@SVector([1.0, 0.0, 0.0]), p),
		$ps,
	)
end

# ╔═╡ cb071d0a-345d-437d-9bc5-960c382e58d6
md"""
It's about 4 times faster! This seems reasonable since we used 4 thread here.
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
# ╟─861210cf-10ee-4367-817b-f2fc446dd671
# ╠═ca40e65a-ab7e-4fb9-a708-88ec8602eb42
# ╠═436cd061-93ea-45ec-a606-a09b2dd476f0
# ╟─c96d99bd-0d56-41dd-ac7a-57c5bffd9fc0
# ╟─a67cc8ad-d8ef-4830-8068-8aed7062377a
# ╠═f1c0022f-c12f-4c61-b6a0-61c2debe840d
# ╠═c07e6957-a153-4bfa-a2a9-3ce6c4857922
# ╠═709e5550-c0dd-46bc-ac0d-77c83b648d22
# ╠═bde73ff2-9fc3-4708-baed-03a9e56c8337
# ╠═0c25ec5b-cb24-4c1e-80bd-3ba748119204
# ╠═043baaf9-ffb5-4c26-be6c-40feaea960ea
# ╠═3509efff-7beb-4c51-9217-4e9a1f2618e0
# ╠═57d5c854-9f9c-4080-adda-c5484f9e449e
# ╠═23784b92-7280-4d56-a1f9-24a546383b72
# ╠═060d936d-c759-4064-9302-a454fa107bb7
# ╠═1f27d62d-674a-4dfd-8912-2689515f17bc
# ╟─cea8ce9f-f657-44b9-b2ed-de3f3983ad08
# ╠═f8357564-8cf5-4329-86da-ea182471e0c9
# ╠═c2326f0b-356f-4353-b1e4-98960b4f4903
# ╠═d386b7f7-a4e8-41b6-a8be-b26cc657db85
# ╟─757aa797-177e-4e45-8a27-2e857ba17e38
# ╟─51e88fd0-e199-40fa-add1-a982db7bd27c
# ╠═0b809325-6ac4-4326-8e07-0b0324fd3a6d
# ╠═cdb8aac6-232d-470c-98aa-839d93fc20fc
# ╠═8596f5af-3696-4d22-a847-49b76ca6a373
# ╠═82543bf0-1b36-4511-8651-87d4492169cc
# ╠═b2f35677-cf25-42e3-8fa6-124d0186d0a7
# ╟─b77c5a71-e2d8-4a2d-bcd0-8c9000e21033
# ╠═7a3385b5-eb08-4625-8268-348a002132b7
# ╠═c948a3b4-0af1-44cb-8300-331baf343581
# ╟─daa14169-be2b-4802-9e95-7b309935f4e5
# ╠═1425adbd-6aab-4a41-85c3-95c85acf1bd0
# ╠═50a5f536-eeee-4053-8405-603c739bbf35
# ╟─c88c7ea8-b6c7-4a6c-af16-8d01ab8ebcf6
# ╠═03db62b2-ff33-4e3c-9c6c-0943fbd9cc19
# ╟─e81bdefd-77e3-4b23-9ade-c9f8ee25535c
# ╠═746db25d-f176-42d8-bec7-b9c9e159d5c6
# ╠═1c08555c-ba4d-405e-a7de-4f53656556e9
# ╠═2fd4f919-9c75-4572-8562-879a31ad1c46
# ╟─0e42e5c8-b690-45eb-be03-1a640020adc4
# ╠═da4a3ad9-eb52-440e-bcb6-951faffc4cdc
# ╟─81b08415-d45d-40c2-bfb7-ee82c6d10e09
# ╠═e586c612-bf08-4eaa-aa81-a50adc934017
# ╟─cb071d0a-345d-437d-9bc5-960c382e58d6
# ╟─8b6135cb-32a9-4849-8fde-e6d8b49a4fc9
