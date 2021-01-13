### A Pluto.jl notebook ###
# v0.12.18

using Markdown
using InteractiveUtils

# ╔═╡ 6de491ce-55b5-11eb-35aa-ff6f9835d819
using Base.Threads

# ╔═╡ 2c7b69f0-55b1-11eb-3320-3bd81851935a
using PlutoUI, BenchmarkTools

# ╔═╡ 5fc8e0d2-55b1-11eb-1e7d-fb21c0dab37c
TableOfContents()

# ╔═╡ 0f4320b0-55ae-11eb-376a-f9f058c388d4
md"""
# SIMD
"""

# ╔═╡ 27c710fa-55af-11eb-39b0-6313a223bb80
md"""
Single instruction, multiple data. This is the simplest form of parallelism and just means that a processor can run multiple commands simultaneously on a specially structured data. SIMD is parallelism within a single core.

A popular example of structured data is `isbits`. This is data that is packed very efficiently in memory, which allows LLVM to autovectorize our code (this is different that vectorization in the for loop vs. map/comprehension sense!).

In Julia, structs that can be fully inferred (e.g., immutable, don't have fields referencing other objects) is one example of `isbits`:
"""

# ╔═╡ 51913024-55ae-11eb-0636-9789c9613afc
struct MyComplex
	real::Float64
	imag::Float64
end

# ╔═╡ f4f8dc30-55ae-11eb-3afc-91a09f5ca3fe
MyComplex |> isbitstype

# ╔═╡ 8bc48b50-55af-11eb-1270-e727ff812c57
z = MyComplex(rand(), rand())

# ╔═╡ 9684519e-55af-11eb-2a4b-cf8c60bb3939
z |> isbits

# ╔═╡ 419c8ce2-55b1-11eb-3558-4b57126ef7a5
md"""
If we look at the LLVM IR for a simple operation on our data, we can see the automatic vectorization in action:
"""

# ╔═╡ f3e936e4-55b0-11eb-292e-5376121189da
Base.:+(x::MyComplex,y::MyComplex) = MyComplex(x.real+y.real,x.imag+y.imag)

# ╔═╡ fb135560-55b0-11eb-1098-6f7819d8d064
Base.:/(x::MyComplex,y::Int) = MyComplex(x.real/y,x.imag/y)

# ╔═╡ fb13cf60-55b0-11eb-0558-8fe3633972ce
average(x::Vector{MyComplex}) = sum(x)/length(x)

# ╔═╡ 094f29bc-55b1-11eb-2e4d-d9f99bee1544
arr = [MyComplex(rand(), rand()) for i in 1:100]

# ╔═╡ fb1822e0-55b0-11eb-12d3-3f3fcd1543f5
with_terminal() do
	@code_llvm average(arr)
end

# ╔═╡ 6d5bd45a-55b1-11eb-2e3e-997f77403171
md"""
In the output above we see statements like `%28 = load <2 x double>, <2 x double>* %3`, which means that 2 multiplications `*` are happening simultaneously for this particular call.
"""

# ╔═╡ c0bc1e06-55b2-11eb-3cda-cfd444a82ddc
md"""
What we did above is an example of **loop-level parallelism** (AKA loop vectorization), which means that our compiler converted what we wrote above to for loops (like `sum` just being a `+` op used multiple times), prove that the iterates are independent, then automatically generated the SIMD code from that. Compilers can also do a non-looping verison when asked, but this is usually much less performant unless you happen to have a problem that can't really be handled with loops (very rare).

**Summary:**
* Communication in SIMD is due to locality: if things are local the processor can automatically setup the operations.

* There's no real worry about "getting it wrong": you cannot overwrite pieces from different parts of the arithmetic unit, and if SIMD is unsafe then it just won't auto-vectorize.

* Suitable for operations measured in ns.

The next level up is multithreading.
"""

# ╔═╡ 069f9e12-55b4-11eb-2852-0d298ceaad18
md"""
# Multithreading
"""

# ╔═╡ 98fc6fc6-55b5-11eb-2b88-7b7e54e05649
md"""
## Shared memory
"""

# ╔═╡ 9e464c4a-55b5-11eb-3d66-15af6af8d985
md"""
This example below shows what happens when our threads are all trying to access data stored in the same heap:
"""

# ╔═╡ 07913ab8-55b4-11eb-2989-3bc2a6c9bc14
begin
	acc = 0
	@threads for i in 1:10_000
	    global acc
	    acc += 1
	end
	acc
end

# ╔═╡ 07a8983e-55b4-11eb-0a4c-0f0acd512c59
md"""
This is definitely not 10_000. In [L05](https://icweaver.github.io/18337/lecture5/index.html) we saw that we could make this kind of process thread safe by giving each thread its own cache so that the threads don't keep overwriting each other. In this case though, we want this global variable `acc` to be aware of each thread so that its value can update accordingly. For example in a nice progress bar as our multithreaded program runs. A nice way of doing this is with the `Atomic` abstraction. This tells the code to make thread B wait until thread A has finished its computation (much like the concurrency example): 
"""

# ╔═╡ c6a79ad2-55b9-11eb-30ea-27645ea0a248
function add_atomic()
	acc = Atomic{Int64}(0)
	@threads for i in 1:10_000
		atomic_add!(acc, 1)
	end
	return acc
end

# ╔═╡ 6f15e99c-55c1-11eb-0191-85575e42529a
add_atomic()

# ╔═╡ e74f2082-55c0-11eb-367c-abf872e8b2a7
md"""
If we want to do more complex atomic operation,s we can use **locks:**
"""

# ╔═╡ 95481622-55c2-11eb-0c4a-b71daddfb954
md"""
### `SpinLock`
"""

# ╔═╡ a3786c60-55c2-11eb-0258-1dc45d749186
md"""
Here we lock our thread with `lock`, do whatever computations we want, then unlock the thread with `unlock`:
"""

# ╔═╡ 088de166-55c1-11eb-3c77-7f0aeeed80be
const acc_lock = Ref{Int64}(0)

# ╔═╡ 09542330-55c1-11eb-36d2-bb4d491755f2
const splock = SpinLock()

# ╔═╡ 097cced4-55c1-11eb-0548-1bf03e934033
function add_splock()
	@threads for i in 1:10_000
		lock(splock)
		acc_lock[] += 1 # Can put anything here
		unlock(splock)
	end
	return acc_lock
end

# ╔═╡ f5003e62-55c2-11eb-38f0-217011b653a0
md"""
The dowside to this though is if our inner computations also happen to use locking because then we would not be thread safe anymore. To avoid this, `SpinLock` keeps itself locked if it sees an inner multithreaded procecess trying to use its own locking again. The side effec though is that we are now trapped in our thread! We can get around this with a `ReentrantLock`:
"""

# ╔═╡ 51be4124-55c5-11eb-36a7-231d7f9534fc
py"""
import numpy as np
import pickle

def load_pickle(fpath):
	   with open(fpath, "rb") as f:
			   data = pickle.load(f)
	   return data
"""
load_pickle = py"load_pickle"

# ╔═╡ d35dcf8e-55c9-11eb-3645-f1fa5b35ee6b
f(x::Int, y::Float64, z::Int) =  x + y + z

# ╔═╡ 8a5bbd62-55cb-11eb-3db8-8333f448ffa0
Measurement[2]

# ╔═╡ d7ad3bcc-55c9-11eb-1215-2f46fe6a41f8
f(1, 2.0, 3.)

# ╔═╡ ce52ae2c-55c1-11eb-0585-9544ebf85991
begin
	const acc_lock_rsp = Ref{Int64}(0)
	const rsplock = ReentrantLock()
	function add_rsplock()
		@threads for i in 1:10_000
			lock(rsplock)
			acc_lock_rsp[] += 1 # Can put anything here
			unlock(rsplock)
		end
		return acc_lock_rsp
	end
end

# ╔═╡ a931dff0-55c1-11eb-1aff-1f3ea975cd9f
with_terminal() do
	@btime add_atomic()
	@btime add_splock()
	@btime add_rsplock()
end

# ╔═╡ Cell order:
# ╟─5fc8e0d2-55b1-11eb-1e7d-fb21c0dab37c
# ╟─0f4320b0-55ae-11eb-376a-f9f058c388d4
# ╟─27c710fa-55af-11eb-39b0-6313a223bb80
# ╠═51913024-55ae-11eb-0636-9789c9613afc
# ╠═f4f8dc30-55ae-11eb-3afc-91a09f5ca3fe
# ╠═8bc48b50-55af-11eb-1270-e727ff812c57
# ╠═9684519e-55af-11eb-2a4b-cf8c60bb3939
# ╟─419c8ce2-55b1-11eb-3558-4b57126ef7a5
# ╠═f3e936e4-55b0-11eb-292e-5376121189da
# ╠═fb135560-55b0-11eb-1098-6f7819d8d064
# ╠═fb13cf60-55b0-11eb-0558-8fe3633972ce
# ╠═094f29bc-55b1-11eb-2e4d-d9f99bee1544
# ╠═fb1822e0-55b0-11eb-12d3-3f3fcd1543f5
# ╟─6d5bd45a-55b1-11eb-2e3e-997f77403171
# ╟─c0bc1e06-55b2-11eb-3cda-cfd444a82ddc
# ╟─069f9e12-55b4-11eb-2852-0d298ceaad18
# ╠═6de491ce-55b5-11eb-35aa-ff6f9835d819
# ╟─98fc6fc6-55b5-11eb-2b88-7b7e54e05649
# ╟─9e464c4a-55b5-11eb-3d66-15af6af8d985
# ╠═07913ab8-55b4-11eb-2989-3bc2a6c9bc14
# ╟─07a8983e-55b4-11eb-0a4c-0f0acd512c59
# ╠═c6a79ad2-55b9-11eb-30ea-27645ea0a248
# ╠═6f15e99c-55c1-11eb-0191-85575e42529a
# ╟─e74f2082-55c0-11eb-367c-abf872e8b2a7
# ╟─95481622-55c2-11eb-0c4a-b71daddfb954
# ╟─a3786c60-55c2-11eb-0258-1dc45d749186
# ╠═088de166-55c1-11eb-3c77-7f0aeeed80be
# ╠═09542330-55c1-11eb-36d2-bb4d491755f2
# ╠═097cced4-55c1-11eb-0548-1bf03e934033
# ╟─f5003e62-55c2-11eb-38f0-217011b653a0
# ╠═51be4124-55c5-11eb-36a7-231d7f9534fc
# ╠═d35dcf8e-55c9-11eb-3645-f1fa5b35ee6b
# ╠═8a5bbd62-55cb-11eb-3db8-8333f448ffa0
# ╠═d7ad3bcc-55c9-11eb-1215-2f46fe6a41f8
# ╠═ce52ae2c-55c1-11eb-0585-9544ebf85991
# ╠═a931dff0-55c1-11eb-1aff-1f3ea975cd9f
# ╠═2c7b69f0-55b1-11eb-3320-3bd81851935a
