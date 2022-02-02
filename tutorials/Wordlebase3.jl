### A Pluto.jl notebook ###
# v0.17.7

using Markdown
using InteractiveUtils

# ╔═╡ 164dc723-623f-411a-83d9-797b1291931d
using BenchmarkTools, DataFrames, PlutoUI  # attach packages we will use

# ╔═╡ fb19122c-8449-11ec-36bd-1f7d45b862cc
md"""
# Julia programming and Wordle

[Wordle](https://en.wikipedia.org/wiki/Wordle) has generated a great deal of interest and has been used to illustrate several aspects of programming in various languages.

This posting presents some [Julia](https://julialang.org) functions motivated by Wordle problems.
Part of the purpose is to illustrate the unique nature of Julia as a dynamically-typed language with a just-in-time (JIT) compiler.
It allows you to write "generic", both in the common meaning of "general purpose" and in the technical meaning of generic functions, and performative code.

This posting originated from a conversation on the Julia [discourse channel](https://discourse.julialang.org/t/rust-julia-comparison-post/75403) referring to a case where Julia code to perform a certain task was horribly slow - taking over 4 days to determine the "best" initial guess, according to a particular criterion.

In situations like this the Julia community inevitably responds by modifying the code to run much faster.
Someone joked that we wouldn't be satisfied until we could do that task in less than 1 second.

The code in this posting does so.

## Wordle responses as base-3 numbers

If you are not familiar with the rules of Wordle, please check the [Wikipedia page](https://en.wikipedia.org/wiki/Wordle).
It is a word game with the objective of guessing a 5-letter word.

After the player submits a guess each letter is marked as green, yellow or gray according to whether it appears in the target word at that position (green), at another position (yellow), or does not occur.
As a recovering mathematician I realized that the response could be represented as a 5-digit, base-3 number, say by assigning green to be 2, yellow to be 1 and gray to be 0.

In the game shown on the Wikipedia page, the initial guess is "arise", the target is "rebus" and the response is gray, yellow, gray, yellow, yellow.

A Julia function to convert a guess and a target to an integer corresponding to this pattern is
"""

# ╔═╡ aa5a3223-9616-4148-b3ab-fabf68327dfa
function index(guess, target)
    value = 0
    for (g, t) in zip(guess, target)
        value *= 3
        value += (g == t ? 2 : Int(g ∈ target))
    end
    return value
end

# ╔═╡ 3d0909bb-28d9-431b-ae99-ccf7ca717e97
md"""
We would call such a function as, e.g.
"""

# ╔═╡ 6cae0843-5f9e-4439-b5b4-9292c7818390
index("arise", "rebus")

# ╔═╡ 7e558835-7767-477d-a063-066a7d2f2791
md"""
That is, the pattern gray, yellow, gray, yellow, yellow corresponds to the base-3 integer `01011`, which is 31 in decimal,
"""

# ╔═╡ 54d789cb-d5d8-4366-a907-8a38ee66e307
index("route", "rebus")

# ╔═╡ 6d621dd7-8042-4427-9eba-af2ff10b1c69
md"""
and the pattern green, gray, yellow, gray, yellow is `20101` in base-3 or 172 in decimal.

## Examining the `index` function

Just as Sherlock Holmes found it interesting that the dog didn't bark in the night, we should find this function interesting for what it doesn't include.

The arguments and the local variables are not given explicit types.
The only requirement on the arguments is that `zip(guess, target)` can be evaluated to produce pairs of values, `g` and `t`, that can be compared for equality, `g == t`.

One of the great advantages of dynamically-types languages with a REPL (read-eval-print-loop) like Julia is that we can easily check `zip` produces (or just read the documentation returned by `?zip`).
"""

# ╔═╡ a8bca7e4-c81c-463b-b16c-8ef93a6b6acf
collect(zip("arise", "rebus"))

# ╔═╡ c876e8b3-59ff-4cb7-a5c3-465b576626a6
md"""
The rest of the function is a common pattern - initialize `value`, which will be the result, modify `value` in a loop, and return it.
The Julia expression
```jl
value *= 3
```
indicates, as in several other languages, that `value` is to be multiplied by 3 in-place.

An expression like
```jl
g == t ? 2 : Int(g  ∈ target)
```
is a *ternary operator* expression (so-called because the operator takes three arguments).
It evaluates the condition, `g == t`, and returns `2` if the condition is true or the value of the Boolean expression `g  ∈ target`, converted to an `Int`, if it is false.

The operation of multiplying by 3 and adding 2 or 1 or 0 is an implementation of [Horner's method](https://en.wikipedia.org/wiki/Horner%27s_method) for evaluating a polynomial.

The function is remarkable because it is both general and compact.
Even more remarkable is that it will be very, very fast after its first usage triggers compilation.

We won't go into detail about the Julia compiler except to note that compilation is performed for specific *method signatures* not for general method definitions.

There are several functions and macros in Julia that allow for inspection at different stages of compilation.
One of the most useful is the macro `@code_warntype` which is used to check for situations where type inference has not been successful.
Applying it as
```jl
@code_warntype index("arise", "rebus")
```
will show the type inference is based on concrete types (`String`) for the arguments.

Some argument types are handled more efficiently than others.
Without going in to details we note that if we take advantage of the fact that we have exactly 5 characters in each argument we can use an `NTuple`, which is an ordered, fixed-length collection.

Using the `@benchmark` macro from the `BenchmarkTools` package shows
"""

# ╔═╡ 6206bdbf-67e2-4469-98dc-3e62b75de93d
@benchmark index(g, t)  setup = (g = "arise"; t = "rebus")

# ╔═╡ a4e3bf91-00e8-4b5e-8b0c-04e39b825740
@benchmark index(g, t) setup=(g=NTuple{5,Char}("arise"); t=NTuple{5,Char}("rebus"))

# ╔═╡ 9bb81a4a-7c85-4cba-804a-d9e8a3d06141
md"""
That is, the version using the fixed-length structure is nearly 4 times as fast as that using the variable-length `String` structure.
(Also, for those who know the distinction, tuples can be passed on the stack whereas a `String` must be heap allocated.)

The details aren't as important as the fact that you can exert a high level of control and optimization of very general code and you can test and benchmark the code interactively.

## Determining the words that match a pattern

The solutions in Wordle are from a list of 2,315 5-letter English words.

For this [Pluto](https://github.com/fonsp/Pluto.jl) notebook we read them as a `String` from a local resource for security.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
BenchmarkTools = "~1.2.2"
DataFrames = "~1.3.2"
PlutoUI = "~0.7.33"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.1"
manifest_format = "2.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "940001114a0147b6e4d10624276d56d531dd9b49"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.2"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "44c37b4636bc54afac5c574d2d02b625349d6582"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.41.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "ae02104e835f219b8930c7664b8012c93475c340"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.2"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "0b5cfbb704034b5b4c1869e36634438a047df065"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "da2314d0b0cb518906ea32a497bb4605451811a4"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.33"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "db3a23166af8aebf4db5ef87ac5b00d36eb771e2"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "bb1064c9a84c52e277f1096cf41434b675cd368b"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─fb19122c-8449-11ec-36bd-1f7d45b862cc
# ╠═aa5a3223-9616-4148-b3ab-fabf68327dfa
# ╟─3d0909bb-28d9-431b-ae99-ccf7ca717e97
# ╠═6cae0843-5f9e-4439-b5b4-9292c7818390
# ╟─7e558835-7767-477d-a063-066a7d2f2791
# ╠═54d789cb-d5d8-4366-a907-8a38ee66e307
# ╟─6d621dd7-8042-4427-9eba-af2ff10b1c69
# ╠═a8bca7e4-c81c-463b-b16c-8ef93a6b6acf
# ╟─c876e8b3-59ff-4cb7-a5c3-465b576626a6
# ╠═164dc723-623f-411a-83d9-797b1291931d
# ╠═6206bdbf-67e2-4469-98dc-3e62b75de93d
# ╠═a4e3bf91-00e8-4b5e-8b0c-04e39b825740
# ╠═9bb81a4a-7c85-4cba-804a-d9e8a3d06141
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
