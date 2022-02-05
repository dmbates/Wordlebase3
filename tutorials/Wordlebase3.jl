### A Pluto.jl notebook ###
# v0.17.7

using Markdown
using InteractiveUtils

# ╔═╡ 152d2f2c-2f0b-4cc4-a42c-adb0200289ec
using DataFrames, PlutoUI, Primes, Random

# ╔═╡ fb19122c-8449-11ec-36bd-1f7d45b862cc
md"""
# Wordle and the Art of Julia Programming

[Wordle](https://en.wikipedia.org/wiki/Wordle) is a recently developed, extremely popular word game that has already spawned many imitators such as [Primel](https://converged.yt/primel/).

This posting presents some [Julia](https://julialang.org) functions motivated by Wordle problems.
Part of the purpose is to illustrate the unique nature of Julia as a dynamically-typed language with a just-in-time (JIT) compiler.
It allows you to write "generic", both in the common meaning of "general purpose" and in the technical meaning of generic functions, and performative code.

This posting originated from a conversation on the Julia [discourse channel](https://discourse.julialang.org/t/rust-julia-comparison-post/75403) referring to a case where Julia code to perform a certain Wordle-related task - determine the "best" initial guess in a Wordle game - was horribly slow.
Julia code described in a [Hacker News](https://news.ycombinator.com/) posting took several hours to do this.

In situations like this the Julia community inevitably responds with suggested modifications to make the code run faster.
Someone joked that we wouldn't be satisfied until we could do that task in less than 1 second, and we did.

The code in this posting can be used to solve a Wordle game very rapidly, as well as related games like Primel.

> **WARNING** The code in this notebook has the potential to make playing Wordle quite boring. If you are enjoying playing Wordle you may want to stop reading now.

Before beginning we attach several packages that we will use in this notebook.
"""

# ╔═╡ e439fbf9-e4b7-4453-b446-86ca23b8e9f0
md"""
## Target pools

If you are not familiar with the rules of Wordle, please check the [Wikipedia page](https://en.wikipedia.org/wiki/Wordle).
It is a word game with the objective of guessing a 5-letter English word, which we will call the "target".
The target word is changed every day but it is always chosen from a set of 2315 words, which we will call the "target pool".

For this notebook we download the Wordle target pool from a github.com site.
In practice it would usually be loaded from a file on a local file system.
"""

# ╔═╡ f7b66c9f-edd5-4e5b-bda3-56246bdcd763
wordlestrings = split(
	read(
		download(
			"https://raw.githubusercontent.com/dmbates/Wordlebase3/main/tutorials/words.txt"
		),
		String
	)
)

# ╔═╡ 66ade745-5974-4163-934c-9c371e62fe65
md"""
We call this pool `wordlestrings` because it is stored as a vector of `Strings` - well actually `SubString`s of one big `String`.
"""

# ╔═╡ 06debaa5-e91d-4276-9a5a-ce7670ccf894
typeof(wordlestrings)

# ╔═╡ 6da44056-4bc1-4fec-8a97-51dbb730142f
md"""
Later we will switch to a more efficient storage mode as a vector of `NTuple{5,Char}` or `NTuple{5,UInt8}` which allows us to take advantage of the fact that each substring is exactly 5 characters long.

Speaking of which, it would be a good idea to check that this collection has the properties we were told it had.
It should be a vector of 2315 strings, each of which is 5 characters.
"""

# ╔═╡ 59fee6da-1898-4799-bfc9-4ea6f553c3fb
length(wordlestrings)

# ╔═╡ a2e912fa-ab82-4c07-8af4-82115118b170
all(w -> length(w) == 5, wordlestrings)

# ╔═╡ 031aeb1a-f3eb-4256-b7f3-5412b352d4b8
md"""
That last expression may look, well, "interesting".
It is a way of checking that a function, in this case an anonymous function expressed using the "stabby lambda" syntax, returns `true` for each element of an iterator, in this case the vector `wordlestrings`.
You can read the whole expression as "for each word `w` in `wordlestrings` check that `length(w)` is 5".

These words are supposed to be exactly 5 letters long but it never hurts to check.
I've been a data scientist for several decades and one of the first lessons in the field is to [trust, but verify](https://en.wikipedia.org/wiki/Trust%2C_but_verify) any claims about the data you are provided.

While discussing this target pool we will form the alternative representations
"""

# ╔═╡ aabc8f2a-5d4b-4ba2-9350-a749dc842aa0
wordlechartuples = NTuple{5,Char}.(wordlestrings)

# ╔═╡ ec4426b3-18ab-49ca-8861-921c45f4f1e3
typeof(wordlechartuples)

# ╔═╡ 69dbe284-a18b-4cba-aaa5-9e65b2887518
wordleuinttuples = NTuple{5,UInt8}.(wordlestrings)

# ╔═╡ 6f39b935-9fa2-4eec-abd7-cb67d1eb4a4b
md"""
These expressions use the [dot syntax for vectorizing functions](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized).
That is the "`.`" between, say, `NTuple{5,Char}` and the left parenthesis, indicates that the operation of converting a `String` to a 5-tuple of `Char`s is to be applied to each element of the vector, returning a vector.

These conversions could also be written as [comprehensions](https://docs.julialang.org/en/v1/manual/arrays/#man-comprehensions), which is another syntax for generating an array from an array.
"""

# ╔═╡ d6850a2c-9470-4c2f-aa04-8be1abada8ce
[NTuple{5,Char}(w) for w in wordlestrings]

# ╔═╡ d380eacc-e17f-4f99-b6d0-96581a299d78
md"""
While discussing these conversions we should also generate the target pool for Primel, which is all primes that can be represented as 5-digit base-10 numbers.
"""

# ╔═╡ 7f87168c-da09-41a0-b766-ae6e4d8a1f4f
primelstrings = [lpad(p, 5, '0') for p in primes(99999)]

# ╔═╡ 214185a7-1ee2-438a-a33b-8710aa4a9e2a
length(primelstrings)

# ╔═╡ ac96f336-6301-4188-af28-7f34119622c4
last(primelstrings, 10)

# ╔═╡ 844cc5f3-1ff1-4a08-875e-5a6fac5b27a9
primelchartuples = NTuple{5,Char}.(primelstrings)

# ╔═╡ 7f59cb6c-e0c2-46bd-8d21-d27237705f82
primeluinttuples = [NTuple{5,UInt8}([c - '0' for c in p]) for p in primelstrings]

# ╔═╡ 4b27131d-f656-4469-8aaf-2d289aac292f
md"""
## Game play

A Wordle game is a dialog between the player and an "oracle", which, for the official game, is the web site.
The player submits a question to the oracle and the oracle responds, using information to which the player does not have access.
In this case the information is the target word.
The question is the player's guess - a 5-letter word - and the response is a score for that word.
The score indicates, for each character, whether it matches the character in the same position in the target or it is in the target in another position or it is not in the target at all.

Using the sample game for Wordle #196 from the Wikipedia page for illustration
"""

# ╔═╡ 54c849c4-0699-4682-a716-86c7a2da5aea
PlutoUI.Resource("https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Wordle_196_example.svg/440px-Wordle_196_example.svg.png")

# ╔═╡ 6b3de53d-a726-4bc5-9388-149626a10cf0
md"""
The target is "rebus".

The player's first guess is "arise" and the response, or score, from the oracle is coded as 🟫, 🟨, 🟫, 🟨, 🟨 where 🟫 indicates that the letter is not in the target (neither `a` nor `i` occur in "rebus") and 🟨 indicates that the letter is in the target but not at that position.
(I'm using 🟫 instead of a gray square because I can't find a gray square Unicode character.)

The second guess is "route" for which the response is 🟩, 🟫, 🟨, 🟫, 🟨 indicating that the first letter in the guess occurs as the first letter in the target.

Of course, the colors are just one way of summarizing the response to a guess.
Within a computer program it is easier to use an integer to represent each of the 243 = 3⁵ possible scores.
An obvious way of mapping the result to an integer in the (decimal) range 0:242 by mapping the response for each character to 2 (in target at that position), 1 (in target not at that position), or 0 (not in target) and regarding the pattern as a base-3 number.

In this coding the response for the first guess, "arise", is 01011 in base-3 or 31 in decimal.
The response for the second guess, "route", is 20101 in base-3 or 172 in decimal.

A function to evaluate this score can be written as
"""

# ╔═╡ aa5a3223-9616-4148-b3ab-fabf68327dfa
function score(guess, target)
    s = 0
    for (g, t) in zip(guess, target)
        s *= 3
        s += (g == t ? 2 : Int(g ∈ target))
    end
    return s
end

# ╔═╡ 3d0909bb-28d9-431b-ae99-ccf7ca717e97
md"""
These numeric scores are not on a scale where "smaller is better" or "larger is better".
(It happens that the best score is 242, corresponding to a perfect match, or five green tiles, but that's incidental.)

The score is just a way of representing each of the 243 patterns that can be produced.

We can convert back to colored squares if desired.
"""

# ╔═╡ 8f1d2147-2656-4ce2-b18a-cc3a9eccd769
function tiles(sc)
	result = Char[]
	for _ in 1:5
		sc, r = divrem(sc, 3)
		push!(result, iszero(r) ? '🟫' : (isone(r) ? '🟨' : '🟩'))
	end
	return String(reverse(result))
end

# ╔═╡ 1c83a79d-c79b-404d-90e2-2576eb32b4df
md"For example,"

# ╔═╡ 6cae0843-5f9e-4439-b5b4-9292c7818390
tiles.(score.(("arise", "route", "rules", "rebus"), Ref("rebus")))

# ╔═╡ 37c672a3-3850-4d7b-bd13-922c13389d5e
md"""
## An oracle function

To play a game of Wordle we create an oracle function by fixing the second argument to `score`.
Producing a function by fixing one of the arguments to another function is sometimes called [currying](https://en.wikipedia.org/wiki/Currying) and there is a Julia type, `Base.Fix2`, which fixes second argument of a function like `score`.
"""

# ╔═╡ 94ba016a-0cd9-4284-9960-c0c98807f81f
oracle196 = Base.Fix2(score, "rebus")

# ╔═╡ fd09ce8f-552b-4a95-b935-88a2a5fec042
md"""
We can treat `oracle196` as a function of one argument.
For example,
"""

# ╔═╡ 7f5035be-0414-426e-b8b2-2f4d4f4c6231
tiles.(oracle196.(("arise", "route", "rules", "rebus")))

# ╔═╡ e6808c28-74d0-4734-a8ce-fd8783994d10
md"""
but we can also examine the arguments from which it was constructed if, for example, we want to check what the target is.
"""

# ╔═╡ 1555970d-671f-4af5-9e9d-893850e64728
propertynames(oracle196)

# ╔═╡ d22f52ef-8c67-4783-a4f1-c4bd88380b44
oracle196.x


# ╔═╡ cc9ad93c-7b3e-4ca6-b108-a532b4620ce3
md"""
## Using a guess and score to filter the set of possible solutions

Now we can present a simple Wordle strategy.

1. Start with the original target pool for the game.
2. Choose a guess from the target pool, submit it to the oracle and obtain the score.
3. If the score corresponds to a perfect match, 242 as a raw score or 5 green tiles after conversion, then the guess is the target and we are done.
4. Use the guess and the score to reduce target pool to those targets that would have given this score.
5. Go to 2.

Consider step 4 - use a guess and a score to reduce the target pool.
We could do this with pencil and paper by starting with the list of 2315 words and crossing off those that don't give the particular score from a particular guess.

But that would be tedious, and computers are really good at that kind of thing, so we write a function.
"""

# ╔═╡ 949c440c-dda0-49d9-abaa-7c3835eedc41
function refine(pool, guess, sc)
	return filter(target -> score(guess, target) == sc, pool)
end

# ╔═╡ e1e5b0d9-518b-442d-b5fd-3dc99a8f8e1f
md"""
In our sample game the first guess is "arise" and the score is 31.
"""

# ╔═╡ 06be4b61-d0a8-469f-ad41-a220d69cb383
md"""
Here we needed to know that the oracle returned the score 31 from the guess "arise".
We could instead write the function with the oracle as an argument and evaluate the score on which to filter within the `refine` function.

In Julia we can define several methods for any function name as long as we can distinguish the "signature" of the argument.
This is why every time we define a new function, the response says it is a `(generic function with 1 method)`.

We define another `refine` method which takes a `Function` as the third argument
"""

# ╔═╡ a4e60664-0f16-4f9a-9ddd-7430abf8989d
refine(pool, guess, oracle::Function) = refine(pool, guess, oracle(guess))

# ╔═╡ b0ec2259-4a26-42af-a2de-4f3d8d6f7240
pool1 = refine(wordlestrings, "arise", 31)

# ╔═╡ 83acc99e-7a1b-47ed-b4c2-20eacb76c6b0
length(pool1)

# ╔═╡ 3ea7b446-6ac6-4eea-9618-a6634b93578f
md"""
This definition uses the short-cut, "one-liner", form of Julia function definition.

Here we define one method as an application of another method with the arguments rearranged a bit.
This is a common idiom in Julia.

We can check that there are indeed two method definitions.
"""

# ╔═╡ 3f88f1f3-ef1a-449c-94fd-ce76fa597388
methods(refine)

# ╔═╡ 39466603-a386-46aa-a8ed-11b0f060d4f6
md"""
(the messy descriptions of where the methods were defined is because we're doing this in a notebook) and that the second method works as intended
"""

# ╔═╡ 4cfb8675-d4df-4e8d-92ff-b4e7ae642b1a
refine(wordlestrings, "arise", oracle196)

# ╔═╡ 6da38500-a5bd-4d7c-b4fc-18ab670447bf
md"""
Now we need to choose another guess.
In the sample game, the second guess was "route". 
Interestingly this word is not in the set of possible targets.
"""

# ╔═╡ e28c14a4-86e1-4351-bc2e-1dd55d6da4cc
"route" ∈ pool1

# ╔═╡ 3e5e1fb8-22c0-4b18-bb75-e139bb2df66f
md"""
Choosing a word, or even a non-word, that can't be a target is allowed, and there is some potential for it being useful as a way of screening the possible targets.
But generally it is not a great strategy to waste a guess that can't be the target, especially when only six guesses are allowed.
In our strategy described below we always choose our guesses from the pool.
This is known as [hard mode](https://www.techradar.com/news/wordle-hard-mode) in Wordle, although, from the programmer's point of view it's more like "easy mode".

Anyway, continuing with the sample game
"""

# ╔═╡ 32f04657-1b42-436f-9f23-d84a8f68fa09
pool2 = refine(pool1, "route", oracle196)

# ╔═╡ db179dbe-bbd1-47fd-ac6e-2f90e27992f4
md"""
So we're done - the target word must be "rebus" and the third guess, "rules", in the sample game is redundant.

## Choosing a good guess

Assuming that we will choose our next guess from the current target pool, how should we go about it?
We want a guess that will reduce the size of the target pool as much as possible, but we don't know what that reduction will be until we have submitted the guess to the oracle.

However, we can set this up as a probability problem.
If the target has been randomly chosen from the set of possible targets, which apparently they are, and our pool size is currently `n`, then each word in the pool has probability `1/n` of being the target.
Thus we can evaluate the expected size of the set of possible targets after the next turn for each potential guess, and choose the guess that gives the smallest expected size.

It sounds as if it is going to be difficult to evaluate the expected pool size because we need to loop over every word in the pool as a guess and, for that guess, every word in the pool as a target, evaluate the score and do something with that score.
But it turns out that all we need to know for each potential guess is the number of words in the pool that would give each of the possible scores.
We need a loop within a loop but all the inner loop has to do is evaluate a score and increment some counts.

In mathematical terms, each guess partitions the targets in the current pool into at most 243 [equivalence classes](https://en.wikipedia.org/wiki/Equivalence_class) according to the score from the guess on that target.

The key point here is that the number of words in a given class is both the size of the pool that would result from one of these targets and the number of targets that could give this pool.

Let's start by evaluating the counts of the words in the pool that give each possible score from a given guess.
We will start with a vector of 243 zeros and, for every word in the pool, evaluate the score and increment the count for that score.

We should make a quick detour to discuss a couple of technical points about Julia programming.
In Julia, by default, the indices into an array start at 1, so the position we will increment in the array of sizes is at `score(guess, w) + 1`.
Secondly, instead of allocating an array for the result within the function we will pass the container - a vector of integers of length 243 - as an argument and modify its contents within the function.

There are two reasons we may want to pass the count vector into the function.
First, if this function is to be called many times, we don't want to allocate storage for the result within the function if we can avoid it.
Second, for generality, we want to avoid assuming that the number of classes will always be 243.
If we allocate the storage outside the function then we don't have to build assumptions on its size into the function.

By convention, such "mutating" functions that can change the contents of arguments are given names that end in `!`, as a warning to users that calling the function may change the contents of one or more arguments.
This is just a convention - the `!` doesn't affect the semantics in any way.

Declare the array of bin sizes
"""

# ╔═╡ 7c07671a-2290-4ada-871c-0cf904b4edc3
sizes = zeros(Int, 243)

# ╔═╡ 795e04f3-d730-4620-8f34-3888289cae3a
md"and the function to evaluate the bin sizes"

# ╔═╡ ca9c47b7-32b0-4c66-8e43-5025bd5ffa71
function binsizes!(sizes, words, guess)
	fill!(sizes, 0)    # zero out the counts
	for w in words
		sizes[score(guess, w) + 1] += 1
	end
	return sizes
end

# ╔═╡ 13c133f6-5f72-4758-a314-5960a34b1d3c
md"""
For the first guess, "arise", on the original set `words`, this gives
"""

# ╔═╡ 7cc14ee8-114c-432e-865d-1aa9b757b5f3
binsizes!(sizes, wordlestrings, "arise")

# ╔═╡ 7228fb42-f673-4246-99c0-fa0a347391cc
md"""
Recall that each of these sizes is both the size the pool and the number of targets that would return this pool.
That is, there are 168 targets that would return a score of 0 from this guess and the size of the pool after refining by this guess and a score of 0 would be 168.

Thus, the expected pool size after a first guess of "arise" is the sum of the squared bin sizes divided by the sum of the sizes, which is the current pool size.

For the example of the first guess `"arise"` and the original pool, `words`, the expected pool size after refining by the score for this guess is
"""

# ╔═╡ 9aecbe62-7d6e-4311-82b8-4940e068b2a6
sum(abs2, sizes) / sum(sizes)

# ╔═╡ 1db50e79-21e7-48a6-aab7-c52f1bb05288
md"""
This is remarkable.
We start off with a pool of 2315 possible targets and, with a single guess, will, on average, refining that pool to around 64 possible targets.
"""

# ╔═╡ 9066998e-a9b2-49e1-97a0-f255f5423e3e
md"""
## Optimal guesses at each stage

We now have the tools in place to determine the guess that will produce the smallest expected pool size from a set of possible targets.
First we will create an `expectedsize!` function that essentially duplicates `binsizes!` except that it returns the expected size.
This will be used in an anonymous function passed to `argmin`.
"""

# ╔═╡ 1e6eabe2-7135-4179-af53-87fffd8e5c0a
function expectedsize!(sizes, words, guess)
	binsizes!(sizes, words, guess)
	return sum(abs2, sizes) / length(words)
end

# ╔═╡ ecd9d650-d071-41ad-a81c-c49e0b941dc9
md"""
The word chosen for the first guess in the sample game, "arise", is a good choice.
"""

# ╔═╡ 53231a85-8658-49a4-9127-c1f01f53f9a6
expectedsize!(sizes, wordlestrings, "arise")

# ╔═╡ d18613ad-b460-4c65-8b21-e09f67a44947
md"but not the best choice."

# ╔═╡ 3e683971-5340-4ccc-9c35-56f0246009b5
function bestguess!(sizes, words)
	return argmin(w -> expectedsize!(sizes, words, w), words)
end

# ╔═╡ b7385840-49f1-4022-9ac2-87991f93043a
bestguess!(sizes, wordlestrings)

# ╔═╡ e256e5c9-2225-4bb8-8022-58a05aca7224
expectedsize!(sizes, wordlestrings, "raise")

# ╔═╡ 1d0742f9-37ab-4b79-b116-cf567ffbb1ed
md"""
That is, the optimal first guess in Wordle "hard mode" is "raise".
(A slight variation of this task of choosing the best initial choice was the example in the discourse thread mentioned above.)

To continue playing.
"""

# ╔═╡ 2982eabe-c75e-4bd8-80f0-b63c8b769e79
guess2 = bestguess!(sizes, refine(wordlestrings, "raise", oracle196))

# ╔═╡ 4e41761e-5e4b-42a2-a6a3-a73549d798e4
oracle196("rebus")

# ╔═╡ bf81ba39-23e4-461c-b0b6-cca578f3ab92
md"""
And we are done after 2 guesses.

To write a function that plays a game of Wordle, we pass an oracle function and the initial target pool.
"""

# ╔═╡ 0b715643-a280-4287-9f62-68e520b35e2d
function playgame(oracle::Function, pool)
	guesses, scores, poolsz = similar(pool, 0), String[], Int[] # to record play
	nbins = 3^length(first(pool))
	sizes = zeros(Int, nbins)
	while true
		guess = bestguess!(sizes, pool)
		push!(guesses, guess)
		score = oracle(guess)
		push!(scores, tiles(score))
		push!(poolsz, length(pool))
		score == nbins - 1 && break
		pool = refine(pool, guess, score)
	end
	return DataFrame(guess = guesses, score = scores, pool_size = poolsz)
end

# ╔═╡ 32269cbe-91ce-4f10-bdde-7244b0709dfc
md"""
If we define another `playgame` method that takes a random number generator and a target pool, we can play a game with the target chosen at random.
"""

# ╔═╡ 532ddbc4-f1d9-4de1-9eec-33851e7cc609
function playgame(rng::AbstractRNG, pool)
	return playgame(Base.Fix2(score, rand(rng, pool)), pool)
end

# ╔═╡ a04a07c4-86b9-47db-95bf-06f4492d960b
results = playgame(oracle196, wordlestrings)

# ╔═╡ 73a8cc54-fdd8-47b3-b22d-5262b06c47d3
md"""
First, initialize a random number generator (RNG) for reproducibility with this notebook.

As of Julia v1.7.0 the default RNG is `Xoshiro`
"""

# ╔═╡ e93d993d-490f-4a94-a339-5c77add7bbac
rng = Xoshiro(42);

# ╔═╡ 2926c2b6-e5df-4e1a-a03a-5a1c3b738f6f
playgame(rng, wordlestrings)

# ╔═╡ 6ca2328e-09c9-4da3-bfa8-890fc44e3a28
md"""
None of the functions we have defined are restricted to the Wordle list or the representation of these words as `String`.
"""

# ╔═╡ d16870fa-b830-4824-8fdb-6f7e2df82770
playgame(rng, wordlechartuples)

# ╔═╡ 8131a8a9-32ff-4595-ae70-5c684482fd0e
playgame(rng, primelchartuples)

# ╔═╡ a6faf6e5-c545-42a1-b728-9d5b070917b0
md"""
We can even use `playgame` to play all possible Wordle games and check properties of our strategy for choosing the next guess.
For example, are we guaranteed to complete the game in six or fewer guesses?
What is the average number of guesses to complete the game?

And we may want to consider alternative storage schemes for the original pool.
How do they influence run-time of the game?

But before doing this we should address a glaring inefficiency in the existing `playgame` methods: the initial guess only depends on the `pool` argument and we keep evaluating the same answer at the beginning of every game.
Of all the calls to `bestguess` in the game this is the most expensive call because the pool is largest at the beginning of play.

## Combining the pool and the initial guess

To ensure that the initial guess is consistent with the pool we should store them as parts of a single structure.
And while we are at it, we can also create and store the vector to accumulate the bin sizes and do a bit of error checking.

We declare the type
"""

# ╔═╡ 4ab20246-e7d1-4662-ac8f-3a86fa2c1330
struct GamePool{T}    # T will be the element type
	pool::Vector{T}
	initial::T
	sizes::Vector{Int}
end

# ╔═╡ e5973e7b-9e1f-4706-b8b4-911b7b162c17
md"""
and an external constructor for the type.
Generally the external constructor would have the same name as the type but that is not allowed in Pluto notebooks so we use a lower-case name.
"""

# ╔═╡ c62e39c8-a37d-4cc9-892a-cec0113435c4
function gamepool(pool::Vector{T}) where {T}
	elsz = length(first(pool))
	if !all(==(elsz), length.(pool))
		throw(ArgumentError("lengths of elements of pool are not consistent"))
	end
	sizes = zeros(Int, 3^elsz)
	GamePool(pool, bestguess!(sizes, pool), sizes)
end

# ╔═╡ 2dd64f53-6bed-47f7-bd46-7876e5c8e662
wordlestrgp = gamepool(wordlestrings)

# ╔═╡ 34dc9417-ee42-48e9-ad3b-bebaaf2adfa9
md"""
We can now define a fastgame generic and some methods
"""

# ╔═╡ b18ec6ab-6a40-4929-929d-e49cf215cc4b
function fastgame(oracle::Function, gp::GamePool)
	(; pool, initial, sizes) = gp   # de-structure gp
	sc = oracle(initial)
	guesses, scores, poolsz = [initial], [tiles(sc)], [length(pool)] # to record play
	nscores = length(sizes)
	if sc + 1 ≠ nscores   	# didn't get a lucky first guess
		pool = refine(pool, initial, sc)
		while true
			guess = bestguess!(sizes, pool)
			push!(guesses, guess)
			sc = oracle(guess)
			push!(scores, tiles(sc))
			push!(poolsz, length(pool))
			sc + 1 == nscores && break
			pool = refine(pool, guess, sc)
		end
	end
	return DataFrame(guess = guesses, score = scores, pool_size = poolsz)
end

# ╔═╡ ebf075ff-234c-41dc-95f1-bfe742e1bc57
function fastgame(rng::AbstractRNG, gp::GamePool)
	fastgame(Base.Fix2(score, rand(rng, gp.pool)), gp)
end

# ╔═╡ 2681e794-716b-4d38-81ab-273adfcdb5c7
fastgame(gp::GamePool) = fastgame(Random.GLOBAL_RNG, gp)

# ╔═╡ 5fae51c2-d1b9-4f0f-b109-8f57d084e581
fastgame(wordlestrgp)

# ╔═╡ c102812d-dabf-4bb6-9f4b-5f7d7372f2b5
md"""
If you want to play on the Wordle web site you would need to create an oracle function that somehow entered the guess and converted the tile pattern to a numeric score.

But I don't think it would be very interesting and it would certainly spoil the fun of playing Wordle.

So instead of doing that, let's see what this tells us about the Art of Julia Programming.
"""

# ╔═╡ 6d621dd7-8042-4427-9eba-af2ff10b1c69
md"""
## Examining the `score` function

In the Sherlock Holmes story [The Adventure of Silver Blaze](thttps://en.wikipedia.org/wiki/The_Adventure_of_Silver_Blaze) there is a famous exchange where Holmes remarks on "the curious incident of the dog in the night-time" (see the link).
The critical clue in the case is not what happened but what didn't happen - the dog didn't bark.

Just as Holmes found it interesting that the dog didn't bark, we should find the functions in this notebook interesting for what they don't include.
For the most part the arguments aren't given explicit types.

Knowing the concrete types of arguments is very important when compiling functions, as is done in Julia, but these functions are written without explicit types.

Consider the `score` function which we reproduce here

```jl
function score(guess, target)
    s = 0
    for (g, t) in zip(guess, target)
        s *= 3
        s += (g == t ? 2 : Int(g ∈ target))
    end
    return s
end
```

The arguments to `score` can be any type.
In fact, formally they are of an abstract type called `Any`.

So how do we make sure that the actual arguments make sense for this function?
Well, the first thing that is done with the arguments is to pass them to `zip(guess, target)` to produce pairs of values, `g` and `t`, that can be compared for equality, `g == t`.
In a sense `score` delegates the task of checking that the arguments are sensible to the `zip` function.

For those unfamiliar with zipping two or more iterators, we can check what the result is.
"""

# ╔═╡ a8bca7e4-c81c-463b-b16c-8ef93a6b6acf
collect(zip("arise", "rebus"))

# ╔═╡ c876e8b3-59ff-4cb7-a5c3-465b576626a6
md"""
One of the great advantages of dynamically-typed languages with a REPL (read-eval-print-loop) like Julia is that we can easily check what `zip` produces in a couple of examples (or even read the documentation returned by `?zip`, if we are desperate).

The rest of the function is a common pattern - initialize `s`, which will be the result, modify `s` in a loop, and return it.
The Julia expression
```jl
s *= 3
```
indicates, as in several other languages, that `s` is to be multiplied by 3 in-place.

An expression like
```jl
g == t ? 2 : Int(g  ∈ target)
```
is a *ternary operator* expression (the name comes from the operator taking three arguments).
It evaluates the condition, `g == t`, and returns `2` if the condition is `true`.
If the `g == t` is `false` the operator returns the value of the Boolean expression `g  ∈ target`, converted to an `Int`.
The Boolean expression will return `false` or `true`, which become `0` or `1` when converted to an `Int`.
This is one of the few times that we explicitly convert a result to a particular type.
We do so because `2` is an `Int` and we don't want the type of the value of the ternary operator expression to change depending on the value of its arguments.

The operation of multiplying by 3 and adding 2 or 1 or 0 is an implementation of [Horner's method](https://en.wikipedia.org/wiki/Horner%27s_method) for evaluating a polynomial.

The function is remarkable because it is both general and compact.
Even more remarkable is that it will be very, very fast after its first usage triggers compilation.
That's important because this function will be in a "hot loop".
It will be called many, many times when evaluating the next guess.

We won't go into detail about the Julia compiler except to note that compilation is performed for specific *method signatures* not for general method definitions.

There are several functions and macros in Julia that allow for inspection at different stages of compilation.
One of the most useful is the macro `@code_warntype` which is used to check for situations where type inference has not been successful.
Applying it as
```jl
@code_warntype score("arise", "rebus")
```
will show the type inference is based on concrete types (`String`) for the arguments.

Some argument types are handled more efficiently than others.
Without going in to details we note that we can take advantage of the fact that we have exactly 5 characters and convert the elements of `words` from `String` to `NTuple{5,Char}`, which is an ordered, fixed-length homogeneous collection.

Using the `@benchmark` macro from the `BenchmarkTools` package gives run times of a few tens of nanoseconds for these arguments, and shows that the function applied to the fixed-length collections is faster.
"""

# ╔═╡ 9bb81a4a-7c85-4cba-804a-d9e8a3d06141
md"""
That is, the version using the fixed-length structure is nearly 4 times as fast as that using the variable-length `String` structure.
(For those familiar with what the "stack" and the "heap" are, the main advantage of an `NTuple` is that it can be passed on the stack whereas a `String` must be heap allocated.)

The details aren't as important as the fact that we can exert a high level of control and optimization of very general code and we can test and benchmark the code interactively.

In fact the whole collection of functions can work with `NTuple` representations of the words.
First convert `words` to a vector of tuples
"""

# ╔═╡ 47de77ad-8218-4d5a-8e92-5ea654d598ff
md"""
(Note that for conversion of a single length-5 string the call was `NTuple{5,Char}("rebus")` but for conversion of a vector of length-5 strings the call includes a dot before the opening parenthesis.
This is an example of "dot-broadcasting", which is a very powerful way in Julia of broadcasting scalar functions to arrays or other iterators.

Then we can just pass the result to `playWordle`.
"""

# ╔═╡ 128fdb37-79a4-4e6e-8c0b-e78e307d9830
md"""
We can benchmark both versions to see if the speed advantage for tuples carries over to the higher-level calculation.
However we want to make sure that it is an apples-to-apples comparison so we first select the index of the target then create the oracle from that element of the `words` or the `tuples` vector.
"""

# ╔═╡ c6c40aff-10a2-419f-97fb-f4c25da081ad
md"""
Now there is a speedup of more than a factor of 10 for using tuples.

Of course, there is a glaring inefficiency in the `playWordle` function in that the first guess, `"raise"`, is being recalculated for every game.
We should allow this fixed first guess to be passed as an argument.

While we are revising the function we can clean up a few other places where assumptions on the length of the words is embedded and do some checking of arguments.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Primes = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
DataFrames = "~1.3.2"
PlutoUI = "~0.7.34"
Primes = "~0.5.1"
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
git-tree-sha1 = "8979e9802b4ac3d58c503a20f2824ad67f9074dd"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.34"

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

[[deps.Primes]]
git-tree-sha1 = "984a3ee07d47d401e0b823b7d30546792439070a"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

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
# ╠═152d2f2c-2f0b-4cc4-a42c-adb0200289ec
# ╟─e439fbf9-e4b7-4453-b446-86ca23b8e9f0
# ╟─f7b66c9f-edd5-4e5b-bda3-56246bdcd763
# ╟─66ade745-5974-4163-934c-9c371e62fe65
# ╠═06debaa5-e91d-4276-9a5a-ce7670ccf894
# ╟─6da44056-4bc1-4fec-8a97-51dbb730142f
# ╠═59fee6da-1898-4799-bfc9-4ea6f553c3fb
# ╠═a2e912fa-ab82-4c07-8af4-82115118b170
# ╟─031aeb1a-f3eb-4256-b7f3-5412b352d4b8
# ╠═aabc8f2a-5d4b-4ba2-9350-a749dc842aa0
# ╠═ec4426b3-18ab-49ca-8861-921c45f4f1e3
# ╠═69dbe284-a18b-4cba-aaa5-9e65b2887518
# ╟─6f39b935-9fa2-4eec-abd7-cb67d1eb4a4b
# ╠═d6850a2c-9470-4c2f-aa04-8be1abada8ce
# ╟─d380eacc-e17f-4f99-b6d0-96581a299d78
# ╠═7f87168c-da09-41a0-b766-ae6e4d8a1f4f
# ╠═214185a7-1ee2-438a-a33b-8710aa4a9e2a
# ╠═ac96f336-6301-4188-af28-7f34119622c4
# ╠═844cc5f3-1ff1-4a08-875e-5a6fac5b27a9
# ╠═7f59cb6c-e0c2-46bd-8d21-d27237705f82
# ╟─4b27131d-f656-4469-8aaf-2d289aac292f
# ╟─54c849c4-0699-4682-a716-86c7a2da5aea
# ╟─6b3de53d-a726-4bc5-9388-149626a10cf0
# ╠═aa5a3223-9616-4148-b3ab-fabf68327dfa
# ╟─3d0909bb-28d9-431b-ae99-ccf7ca717e97
# ╠═8f1d2147-2656-4ce2-b18a-cc3a9eccd769
# ╟─1c83a79d-c79b-404d-90e2-2576eb32b4df
# ╠═6cae0843-5f9e-4439-b5b4-9292c7818390
# ╟─37c672a3-3850-4d7b-bd13-922c13389d5e
# ╠═94ba016a-0cd9-4284-9960-c0c98807f81f
# ╟─fd09ce8f-552b-4a95-b935-88a2a5fec042
# ╠═7f5035be-0414-426e-b8b2-2f4d4f4c6231
# ╟─e6808c28-74d0-4734-a8ce-fd8783994d10
# ╠═1555970d-671f-4af5-9e9d-893850e64728
# ╠═d22f52ef-8c67-4783-a4f1-c4bd88380b44
# ╟─cc9ad93c-7b3e-4ca6-b108-a532b4620ce3
# ╠═949c440c-dda0-49d9-abaa-7c3835eedc41
# ╟─e1e5b0d9-518b-442d-b5fd-3dc99a8f8e1f
# ╠═b0ec2259-4a26-42af-a2de-4f3d8d6f7240
# ╠═83acc99e-7a1b-47ed-b4c2-20eacb76c6b0
# ╟─06be4b61-d0a8-469f-ad41-a220d69cb383
# ╠═a4e60664-0f16-4f9a-9ddd-7430abf8989d
# ╟─3ea7b446-6ac6-4eea-9618-a6634b93578f
# ╠═3f88f1f3-ef1a-449c-94fd-ce76fa597388
# ╟─39466603-a386-46aa-a8ed-11b0f060d4f6
# ╠═4cfb8675-d4df-4e8d-92ff-b4e7ae642b1a
# ╟─6da38500-a5bd-4d7c-b4fc-18ab670447bf
# ╠═e28c14a4-86e1-4351-bc2e-1dd55d6da4cc
# ╟─3e5e1fb8-22c0-4b18-bb75-e139bb2df66f
# ╠═32f04657-1b42-436f-9f23-d84a8f68fa09
# ╟─db179dbe-bbd1-47fd-ac6e-2f90e27992f4
# ╠═7c07671a-2290-4ada-871c-0cf904b4edc3
# ╟─795e04f3-d730-4620-8f34-3888289cae3a
# ╠═ca9c47b7-32b0-4c66-8e43-5025bd5ffa71
# ╟─13c133f6-5f72-4758-a314-5960a34b1d3c
# ╠═7cc14ee8-114c-432e-865d-1aa9b757b5f3
# ╟─7228fb42-f673-4246-99c0-fa0a347391cc
# ╠═9aecbe62-7d6e-4311-82b8-4940e068b2a6
# ╟─1db50e79-21e7-48a6-aab7-c52f1bb05288
# ╟─9066998e-a9b2-49e1-97a0-f255f5423e3e
# ╠═1e6eabe2-7135-4179-af53-87fffd8e5c0a
# ╟─ecd9d650-d071-41ad-a81c-c49e0b941dc9
# ╠═53231a85-8658-49a4-9127-c1f01f53f9a6
# ╟─d18613ad-b460-4c65-8b21-e09f67a44947
# ╠═3e683971-5340-4ccc-9c35-56f0246009b5
# ╠═b7385840-49f1-4022-9ac2-87991f93043a
# ╠═e256e5c9-2225-4bb8-8022-58a05aca7224
# ╟─1d0742f9-37ab-4b79-b116-cf567ffbb1ed
# ╠═2982eabe-c75e-4bd8-80f0-b63c8b769e79
# ╠═4e41761e-5e4b-42a2-a6a3-a73549d798e4
# ╟─bf81ba39-23e4-461c-b0b6-cca578f3ab92
# ╠═0b715643-a280-4287-9f62-68e520b35e2d
# ╟─a04a07c4-86b9-47db-95bf-06f4492d960b
# ╟─32269cbe-91ce-4f10-bdde-7244b0709dfc
# ╠═532ddbc4-f1d9-4de1-9eec-33851e7cc609
# ╟─73a8cc54-fdd8-47b3-b22d-5262b06c47d3
# ╠═e93d993d-490f-4a94-a339-5c77add7bbac
# ╠═2926c2b6-e5df-4e1a-a03a-5a1c3b738f6f
# ╟─6ca2328e-09c9-4da3-bfa8-890fc44e3a28
# ╠═d16870fa-b830-4824-8fdb-6f7e2df82770
# ╠═8131a8a9-32ff-4595-ae70-5c684482fd0e
# ╟─a6faf6e5-c545-42a1-b728-9d5b070917b0
# ╠═4ab20246-e7d1-4662-ac8f-3a86fa2c1330
# ╟─e5973e7b-9e1f-4706-b8b4-911b7b162c17
# ╠═c62e39c8-a37d-4cc9-892a-cec0113435c4
# ╠═2dd64f53-6bed-47f7-bd46-7876e5c8e662
# ╟─34dc9417-ee42-48e9-ad3b-bebaaf2adfa9
# ╠═b18ec6ab-6a40-4929-929d-e49cf215cc4b
# ╠═ebf075ff-234c-41dc-95f1-bfe742e1bc57
# ╠═2681e794-716b-4d38-81ab-273adfcdb5c7
# ╠═5fae51c2-d1b9-4f0f-b109-8f57d084e581
# ╟─c102812d-dabf-4bb6-9f4b-5f7d7372f2b5
# ╟─6d621dd7-8042-4427-9eba-af2ff10b1c69
# ╠═a8bca7e4-c81c-463b-b16c-8ef93a6b6acf
# ╟─c876e8b3-59ff-4cb7-a5c3-465b576626a6
# ╟─9bb81a4a-7c85-4cba-804a-d9e8a3d06141
# ╟─47de77ad-8218-4d5a-8e92-5ea654d598ff
# ╟─128fdb37-79a4-4e6e-8c0b-e78e307d9830
# ╟─c6c40aff-10a2-419f-97fb-f4c25da081ad
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
