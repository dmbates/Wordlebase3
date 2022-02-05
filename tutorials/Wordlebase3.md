~~~
<!-- PlutoStaticHTML.Begin -->
<!--
    # This information is used for caching.
    [PlutoStaticHTML.State]
    input_sha = "6f250ee53639d0fce33581c1ac0dd7fbf4c87b822dcc98528816be34dcecc645"
    julia_version = "1.7.1"
-->

<div class="markdown"><h1>Wordle and the Art of Julia Programming</h1>
<p><a href="https://en.wikipedia.org/wiki/Wordle">Wordle</a> is a recently developed, extremely popular word game that has already spawned many imitators such as <a href="https://converged.yt/primel/">Primel</a>.</p>
<p>This posting presents some <a href="https://julialang.org">Julia</a> functions motivated by Wordle problems. Part of the purpose is to illustrate the unique nature of Julia as a dynamically-typed language with a just-in-time &#40;JIT&#41; compiler. It allows you to write &quot;generic&quot;, both in the common meaning of &quot;general purpose&quot; and in the technical meaning of generic functions, and performative code.</p>
<p>This posting originated from a conversation on the Julia <a href="https://discourse.julialang.org/t/rust-julia-comparison-post/75403">discourse channel</a> referring to a case where Julia code to perform a certain Wordle-related task - determine the &quot;best&quot; initial guess in a Wordle game - was horribly slow. Julia code described in a <a href="https://news.ycombinator.com/">Hacker News</a> posting took several hours to do this.</p>
<p>In situations like this the Julia community inevitably responds with suggested modifications to make the code run faster. Someone joked that we wouldn&#39;t be satisfied until we could do that task in less than 1 second, and we did.</p>
<p>The code in this posting can be used to solve a Wordle game very rapidly, as well as related games like Primel.</p>
<blockquote>
<p><strong>WARNING</strong> The code in this notebook has the potential to make playing Wordle quite boring. If you are enjoying playing Wordle you may want to stop reading now.</p>
</blockquote>
<p>Before beginning we attach several packages that we will use in this notebook.</p>
</div>

<pre class='language-julia'><code class='language-julia'>using DataFrames, PlutoUI, Primes, Random</code></pre>



<div class="markdown"><h2>Target pools</h2>
<p>If you are not familiar with the rules of Wordle, please check the <a href="https://en.wikipedia.org/wiki/Wordle">Wikipedia page</a>. It is a word game with the objective of guessing a 5-letter English word, which we will call the &quot;target&quot;. The target word is changed every day but it is always chosen from a set of 2315 words, which we will call the &quot;target pool&quot;.</p>
<p>For this notebook we download the Wordle target pool from a github.com site. In practice it would usually be loaded from a file on a local file system.</p>
</div>

<pre class='language-julia'><code class='language-julia'>wordlestrings = split(
	read(
		download(
			"https://raw.githubusercontent.com/dmbates/Wordlebase3/main/tutorials/words.txt"
		),
		String
	)
)</code></pre>
<pre id='var-wordlestrings' class='documenter-example-output'><code class='code-output'>["aback", "abase", "abate", "abbey", "abbot", "abhor", "abide", "abled", "abode", "abort", "about", "above", "abuse", "abyss", "acorn", "acrid", "actor", "acute", "adage", "adapt", more, "wryly", "yacht", "yearn", "yeast", "yield", "young", "youth", "zebra", "zesty", "zonal"]</code></pre>


<div class="markdown"><p>We call this pool <code>wordlestrings</code> because it is stored as a vector of <code>Strings</code> - well actually <code>SubString</code>s of one big <code>String</code>.</p>
</div>

<pre class='language-julia'><code class='language-julia'>typeof(wordlestrings)</code></pre>
<pre id='var-hash114335' class='pre-class'><code class='code-output'>Vector{SubString{String}} (alias for Array{SubString{String}, 1})</code></pre>


<div class="markdown"><p>Later we will switch to a more efficient storage mode as a vector of <code>NTuple&#123;5,Char&#125;</code> or <code>NTuple&#123;5,UInt8&#125;</code> which allows us to take advantage of the fact that each substring is exactly 5 characters long.</p>
<p>Speaking of which, it would be a good idea to check that this collection has the properties we were told it had. It should be a vector of 2315 strings, each of which is 5 characters.</p>
</div>

<pre class='language-julia'><code class='language-julia'>length(wordlestrings)</code></pre>
<pre id='var-hash491243' class='pre-class'><code class='code-output'>2315</code></pre>

<pre class='language-julia'><code class='language-julia'>all(w -&gt; length(w) == 5, wordlestrings)</code></pre>
<pre id='var-anon17897468717937550708' class='pre-class'><code class='code-output'>true</code></pre>


<div class="markdown"><p>That last expression may look, well, &quot;interesting&quot;. It is a way of checking that if function, in this case an anonymous function expressed using the &quot;stabby lambda&quot; syntax, returns <code>true</code> for each element of an iterator, in this case the vector <code>wordlestrings</code>. You can read the whole expression as &quot;is <code>length&#40;w&#41;</code> equal to <code>5</code> for each word <code>w</code> in <code>wordlestrings</code>&quot;.</p>
<p>These words are supposed to be exactly 5 letters long but it never hurts to check. I&#39;ve been a data scientist for several decades and one of the first lessons in the field is to <a href="https://en.wikipedia.org/wiki/Trust&#37;2C_but_verify">trust, but verify</a> any claims about the data you are provided.</p>
<p>While discussing this target pool we will form the alternative representations</p>
</div>

<pre class='language-julia'><code class='language-julia'>wordlechartuples = NTuple{5,Char}.(wordlestrings)</code></pre>
<pre id='var-wordlechartuples' class='documenter-example-output'><code class='code-output'>[('a', 'b', 'a', 'c', 'k'), ('a', 'b', 'a', 's', 'e'), ('a', 'b', 'a', 't', 'e'), ('a', 'b', 'b', 'e', 'y'), ('a', 'b', 'b', 'o', 't'), ('a', 'b', 'h', 'o', 'r'), ('a', 'b', 'i', 'd', 'e'), ('a', 'b', 'l', 'e', 'd'), ('a', 'b', 'o', 'd', 'e'), ('a', 'b', 'o', 'r', 't'), ('a', 'b', 'o', 'u', 't'), ('a', 'b', 'o', 'v', 'e'), ('a', 'b', 'u', 's', 'e'), ('a', 'b', 'y', 's', 's'), ('a', 'c', 'o', 'r', 'n'), ('a', 'c', 'r', 'i', 'd'), ('a', 'c', 't', 'o', 'r'), ('a', 'c', 'u', 't', 'e'), ('a', 'd', 'a', 'g', 'e'), ('a', 'd', 'a', 'p', 't'), more, ('w', 'r', 'y', 'l', 'y'), ('y', 'a', 'c', 'h', 't'), ('y', 'e', 'a', 'r', 'n'), ('y', 'e', 'a', 's', 't'), ('y', 'i', 'e', 'l', 'd'), ('y', 'o', 'u', 'n', 'g'), ('y', 'o', 'u', 't', 'h'), ('z', 'e', 'b', 'r', 'a'), ('z', 'e', 's', 't', 'y'), ('z', 'o', 'n', 'a', 'l')]</code></pre>

<pre class='language-julia'><code class='language-julia'>typeof(wordlechartuples)</code></pre>
<pre id='var-hash171514' class='pre-class'><code class='code-output'>Vector{NTuple{5, Char}} (alias for Array{NTuple{5, Char}, 1})</code></pre>

<pre class='language-julia'><code class='language-julia'>wordleuinttuples = NTuple{5,UInt8}.(wordlestrings)</code></pre>
<pre id='var-wordleuinttuples' class='documenter-example-output'><code class='code-output'>[(0x61, 0x62, 0x61, 0x63, 0x6b), (0x61, 0x62, 0x61, 0x73, 0x65), (0x61, 0x62, 0x61, 0x74, 0x65), (0x61, 0x62, 0x62, 0x65, 0x79), (0x61, 0x62, 0x62, 0x6f, 0x74), (0x61, 0x62, 0x68, 0x6f, 0x72), (0x61, 0x62, 0x69, 0x64, 0x65), (0x61, 0x62, 0x6c, 0x65, 0x64), (0x61, 0x62, 0x6f, 0x64, 0x65), (0x61, 0x62, 0x6f, 0x72, 0x74), (0x61, 0x62, 0x6f, 0x75, 0x74), (0x61, 0x62, 0x6f, 0x76, 0x65), (0x61, 0x62, 0x75, 0x73, 0x65), (0x61, 0x62, 0x79, 0x73, 0x73), (0x61, 0x63, 0x6f, 0x72, 0x6e), (0x61, 0x63, 0x72, 0x69, 0x64), (0x61, 0x63, 0x74, 0x6f, 0x72), (0x61, 0x63, 0x75, 0x74, 0x65), (0x61, 0x64, 0x61, 0x67, 0x65), (0x61, 0x64, 0x61, 0x70, 0x74), more, (0x77, 0x72, 0x79, 0x6c, 0x79), (0x79, 0x61, 0x63, 0x68, 0x74), (0x79, 0x65, 0x61, 0x72, 0x6e), (0x79, 0x65, 0x61, 0x73, 0x74), (0x79, 0x69, 0x65, 0x6c, 0x64), (0x79, 0x6f, 0x75, 0x6e, 0x67), (0x79, 0x6f, 0x75, 0x74, 0x68), (0x7a, 0x65, 0x62, 0x72, 0x61), (0x7a, 0x65, 0x73, 0x74, 0x79), (0x7a, 0x6f, 0x6e, 0x61, 0x6c)]</code></pre>


<div class="markdown"><p>These expressions use the <a href="https://docs.julialang.org/en/v1/manual/functions/#man-vectorized">dot syntax for vectorizing functions</a>. That is the &quot;<code>.</code>&quot; between, say, <code>NTuple&#123;5,Char&#125;</code> and the left parenthesis, indicates that the operation of converting a <code>String</code> to a 5-tuple of <code>Char</code>s is to be applied to each element of the vector, returning a vector.</p>
<p>These conversions could also be written as <a href="https://docs.julialang.org/en/v1/manual/arrays/#man-comprehensions">comprehensions</a>, which is another syntax for generating an array from an array.</p>
</div>

<pre class='language-julia'><code class='language-julia'>[NTuple{5,Char}(w) for w in wordlestrings]</code></pre>
<pre id='var-hash516208' class='documenter-example-output'><code class='code-output'>[('a', 'b', 'a', 'c', 'k'), ('a', 'b', 'a', 's', 'e'), ('a', 'b', 'a', 't', 'e'), ('a', 'b', 'b', 'e', 'y'), ('a', 'b', 'b', 'o', 't'), ('a', 'b', 'h', 'o', 'r'), ('a', 'b', 'i', 'd', 'e'), ('a', 'b', 'l', 'e', 'd'), ('a', 'b', 'o', 'd', 'e'), ('a', 'b', 'o', 'r', 't'), ('a', 'b', 'o', 'u', 't'), ('a', 'b', 'o', 'v', 'e'), ('a', 'b', 'u', 's', 'e'), ('a', 'b', 'y', 's', 's'), ('a', 'c', 'o', 'r', 'n'), ('a', 'c', 'r', 'i', 'd'), ('a', 'c', 't', 'o', 'r'), ('a', 'c', 'u', 't', 'e'), ('a', 'd', 'a', 'g', 'e'), ('a', 'd', 'a', 'p', 't'), more, ('w', 'r', 'y', 'l', 'y'), ('y', 'a', 'c', 'h', 't'), ('y', 'e', 'a', 'r', 'n'), ('y', 'e', 'a', 's', 't'), ('y', 'i', 'e', 'l', 'd'), ('y', 'o', 'u', 'n', 'g'), ('y', 'o', 'u', 't', 'h'), ('z', 'e', 'b', 'r', 'a'), ('z', 'e', 's', 't', 'y'), ('z', 'o', 'n', 'a', 'l')]</code></pre>


<div class="markdown"><p>While discussing these conversions we should also generate the target pool for Primel, which is all primes that can be represented as 5-digit base-10 numbers.</p>
</div>

<pre class='language-julia'><code class='language-julia'>primelstrings = [lpad(p, 5, '0') for p in primes(99999)]</code></pre>
<pre id='var-primelstrings' class='documenter-example-output'><code class='code-output'>["00002", "00003", "00005", "00007", "00011", "00013", "00017", "00019", "00023", "00029", "00031", "00037", "00041", "00043", "00047", "00053", "00059", "00061", "00067", "00071", more, "99877", "99881", "99901", "99907", "99923", "99929", "99961", "99971", "99989", "99991"]</code></pre>

<pre class='language-julia'><code class='language-julia'>length(primelstrings)</code></pre>
<pre id='var-hash953549' class='pre-class'><code class='code-output'>9592</code></pre>

<pre class='language-julia'><code class='language-julia'>last(primelstrings, 10)</code></pre>
<pre id='var-hash390465' class='documenter-example-output'><code class='code-output'>["99877", "99881", "99901", "99907", "99923", "99929", "99961", "99971", "99989", "99991"]</code></pre>

<pre class='language-julia'><code class='language-julia'>primelchartuples = NTuple{5,Char}.(primelstrings)</code></pre>
<pre id='var-primelchartuples' class='documenter-example-output'><code class='code-output'>[('0', '0', '0', '0', '2'), ('0', '0', '0', '0', '3'), ('0', '0', '0', '0', '5'), ('0', '0', '0', '0', '7'), ('0', '0', '0', '1', '1'), ('0', '0', '0', '1', '3'), ('0', '0', '0', '1', '7'), ('0', '0', '0', '1', '9'), ('0', '0', '0', '2', '3'), ('0', '0', '0', '2', '9'), ('0', '0', '0', '3', '1'), ('0', '0', '0', '3', '7'), ('0', '0', '0', '4', '1'), ('0', '0', '0', '4', '3'), ('0', '0', '0', '4', '7'), ('0', '0', '0', '5', '3'), ('0', '0', '0', '5', '9'), ('0', '0', '0', '6', '1'), ('0', '0', '0', '6', '7'), ('0', '0', '0', '7', '1'), more, ('9', '9', '8', '7', '7'), ('9', '9', '8', '8', '1'), ('9', '9', '9', '0', '1'), ('9', '9', '9', '0', '7'), ('9', '9', '9', '2', '3'), ('9', '9', '9', '2', '9'), ('9', '9', '9', '6', '1'), ('9', '9', '9', '7', '1'), ('9', '9', '9', '8', '9'), ('9', '9', '9', '9', '1')]</code></pre>

<pre class='language-julia'><code class='language-julia'>primeluinttuples = [NTuple{5,UInt8}([c - '0' for c in p]) for p in primelstrings]</code></pre>
<pre id='var-primeluinttuples' class='documenter-example-output'><code class='code-output'>[(0x00, 0x00, 0x00, 0x00, 0x02), (0x00, 0x00, 0x00, 0x00, 0x03), (0x00, 0x00, 0x00, 0x00, 0x05), (0x00, 0x00, 0x00, 0x00, 0x07), (0x00, 0x00, 0x00, 0x01, 0x01), (0x00, 0x00, 0x00, 0x01, 0x03), (0x00, 0x00, 0x00, 0x01, 0x07), (0x00, 0x00, 0x00, 0x01, 0x09), (0x00, 0x00, 0x00, 0x02, 0x03), (0x00, 0x00, 0x00, 0x02, 0x09), (0x00, 0x00, 0x00, 0x03, 0x01), (0x00, 0x00, 0x00, 0x03, 0x07), (0x00, 0x00, 0x00, 0x04, 0x01), (0x00, 0x00, 0x00, 0x04, 0x03), (0x00, 0x00, 0x00, 0x04, 0x07), (0x00, 0x00, 0x00, 0x05, 0x03), (0x00, 0x00, 0x00, 0x05, 0x09), (0x00, 0x00, 0x00, 0x06, 0x01), (0x00, 0x00, 0x00, 0x06, 0x07), (0x00, 0x00, 0x00, 0x07, 0x01), more, (0x09, 0x09, 0x08, 0x07, 0x07), (0x09, 0x09, 0x08, 0x08, 0x01), (0x09, 0x09, 0x09, 0x00, 0x01), (0x09, 0x09, 0x09, 0x00, 0x07), (0x09, 0x09, 0x09, 0x02, 0x03), (0x09, 0x09, 0x09, 0x02, 0x09), (0x09, 0x09, 0x09, 0x06, 0x01), (0x09, 0x09, 0x09, 0x07, 0x01), (0x09, 0x09, 0x09, 0x08, 0x09), (0x09, 0x09, 0x09, 0x09, 0x01)]</code></pre>


<div class="markdown"><h2>Game play</h2>
<p>A Wordle game is a dialog between the player and an &quot;oracle&quot;, which, for the official game, is the web site. The player submits a question to the oracle and the oracle responds, using information to which the player does not have access. In this case the information is the target word. The question is the player&#39;s guess - a 5-letter word - and the response is a score for that word. The score indicates, for each character, whether it matches the character in the same position in the target or it is in the target in another position or it is not in the target at all.</p>
<p>Using the sample game for Wordle #196 from the Wikipedia page for illustration</p>
</div>

<pre class='language-julia'><code class='language-julia'>PlutoUI.Resource("https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Wordle_196_example.svg/440px-Wordle_196_example.svg.png")</code></pre>
<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Wordle_196_example.svg/440px-Wordle_196_example.svg.png" controls="" type="image/png"></img>


<div class="markdown"><p>The target is &quot;rebus&quot;.</p>
<p>The player&#39;s first guess is &quot;arise&quot; and the response, or score, from the oracle is coded as 🟫🟨🟫🟨🟨 where 🟫 indicates that the letter is not in the target &#40;neither <code>a</code> nor <code>i</code> occur in &quot;rebus&quot;&#41; and 🟨 indicates that the letter is in the target but not at that position. &#40;I&#39;m using 🟫 instead of a gray square because I can&#39;t find a gray square Unicode character.&#41;</p>
<p>The second guess is &quot;route&quot; for which the response is 🟩🟫🟨🟫🟨 indicating that the first letter in the guess occurs as the first letter in the target.</p>
<p>Of course, the colors are just one way of summarizing the response to a guess. Within a computer program it is easier to use an integer to represent each of the 243 &#61; 3⁵ possible scores. An obvious way of mapping the result to an integer in the &#40;decimal&#41; range 0:242 by mapping the response for each character to 2 &#40;in target at that position&#41;, 1 &#40;in target not at that position&#41;, or 0 &#40;not in target&#41; and regarding the pattern as a base-3 number.</p>
<p>In this coding the response for the first guess, &quot;arise&quot;, is 01011 in base-3 or 31 in decimal. The response for the second guess, &quot;route&quot;, is 20101 in base-3 or 172 in decimal.</p>
<p>A function to evaluate this score can be written as</p>
</div>

<pre class='language-julia'><code class='language-julia'>function score(guess, target)
    s = 0
    for (g, t) in zip(guess, target)
        s *= 3
        s += (g == t ? 2 : Int(g ∈ target))
    end
    return s
end</code></pre>
<pre id='var-score' class='pre-class'><code class='code-output'>score (generic function with 1 method)</code></pre>


<div class="markdown"><p>These numeric scores are not on a scale where &quot;smaller is better&quot; or &quot;larger is better&quot;. &#40;It happens that the best score is 242, corresponding to a perfect match, or five green tiles, but that&#39;s incidental.&#41;</p>
<p>The score is just a way of representing each of the 243 patterns that can be produced.</p>
<p>We can convert back to colored squares if desired.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function tiles(sc)
	result = Char[] # initialize to an empty array of Char
	for _ in 1:5    # _ indicates we won't use the counter, just loop 5 times
		sc, r = divrem(sc, 3)
		push!(result, iszero(r) ? '🟫' : (isone(r) ? '🟨' : '🟩'))
	end
	return String(reverse(result))
end</code></pre>
<pre id='var-tiles' class='pre-class'><code class='code-output'>tiles (generic function with 1 method)</code></pre>


<div class="markdown"><p>For example,</p>
</div>

<pre class='language-julia'><code class='language-julia'>tiles.(score.(("arise", "route", "rules", "rebus"), Ref("rebus")))</code></pre>
<pre id='var-hash604101' class='documenter-example-output'><code class='code-output'>("🟫🟨🟫🟨🟨", "🟩🟫🟨🟫🟨", "🟩🟨🟫🟨🟩", "🟩🟩🟩🟩🟩")</code></pre>


<div class="markdown"><p>The use of <code>Ref</code> is to make the String, which is an iterator, appear to be a scalar.</p>
<p>We could instead use function composition to evaluate this result</p>
</div>

<pre class='language-julia'><code class='language-julia'>(tiles ∘ score).(("arise", "route", "rules", "rebus"), Ref("rebus"))</code></pre>
<pre id='var-hash115434' class='documenter-example-output'><code class='code-output'>("🟫🟨🟫🟨🟨", "🟩🟫🟨🟫🟨", "🟩🟨🟫🟨🟩", "🟩🟩🟩🟩🟩")</code></pre>


<div class="markdown"><h2>An oracle function</h2>
<p>To play a game of Wordle we create an oracle function by fixing the second argument to <code>score</code>. Producing a function by fixing one of the arguments to another function is sometimes called <a href="https://en.wikipedia.org/wiki/Currying">currying</a> and there is a Julia type, <code>Base.Fix2</code>, which fixes second argument of a function like <code>score</code>.</p>
</div>

<pre class='language-julia'><code class='language-julia'>oracle196 = Base.Fix2(score, "rebus")</code></pre>
<pre id='var-oracle196' class='pre-class'><code class='code-output'>(::Base.Fix2{typeof(Main.workspace#3.score), String}) (generic function with 1 method)</code></pre>


<div class="markdown"><p>We can treat <code>oracle196</code> as a function of one argument. For example,</p>
</div>

<pre class='language-julia'><code class='language-julia'>(tiles ∘ oracle196).(("arise", "route", "rules", "rebus"))</code></pre>
<pre id='var-hash739598' class='documenter-example-output'><code class='code-output'>("🟫🟨🟫🟨🟨", "🟩🟫🟨🟫🟨", "🟩🟨🟫🟨🟩", "🟩🟩🟩🟩🟩")</code></pre>


<div class="markdown"><p>but we can also examine the arguments from which it was constructed if, for example, we want to check what the target is.</p>
</div>

<pre class='language-julia'><code class='language-julia'>propertynames(oracle196)</code></pre>
<pre id='var-hash156147' class='documenter-example-output'><code class='code-output'>(:f, :x)</code></pre>

<pre class='language-julia'><code class='language-julia'>oracle196.x
</code></pre>
<pre id='var-hash346882' class='pre-class'><code class='code-output'>"rebus"</code></pre>


<div class="markdown"><h2>Using a guess and score to filter the set of possible solutions</h2>
<p>Now we can present a simple Wordle strategy.</p>
<ol>
<li><p>Start with the original target pool for the game.</p>
</li>
<li><p>Choose a guess from the target pool, submit it to the oracle and obtain the score.</p>
</li>
<li><p>If the score corresponds to a perfect match, 242 as a raw score or 5 green tiles after conversion, then the guess is the target and we are done.</p>
</li>
<li><p>Use the guess and the score to reduce target pool to those targets that would have given this score.</p>
</li>
<li><p>Go to 2.</p>
</li>
</ol>
<p>Consider step 4 - use a guess and a score to reduce the target pool. We could do this with pencil and paper by starting with the list of 2315 words and crossing off those that don&#39;t give the particular score from a particular guess. But that would be tedious, and computers are really good at that kind of thing, so we write a function.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function refine(pool, guess, sc)
	return filter(target -&gt; score(guess, target) == sc, pool)
end</code></pre>
<pre id='var-refine' class='pre-class'><code class='code-output'>refine (generic function with 1 method)</code></pre>


<div class="markdown"><p>In our sample game the first guess is &quot;arise&quot; and the score is 31.</p>
</div>

<pre class='language-julia'><code class='language-julia'>pool1 = refine(wordlestrings, "arise", 31)</code></pre>
<pre id='var-pool1' class='documenter-example-output'><code class='code-output'>["ester", "loser", "poser", "rebus", "reset", "screw", "serum", "sever", "sewer", "sheer", "shrew", "sneer", "sober", "sower", "sperm", "steer", "stern", "super", "surer", "usher"]</code></pre>

<pre class='language-julia'><code class='language-julia'>length(pool1)</code></pre>
<pre id='var-hash168564' class='pre-class'><code class='code-output'>20</code></pre>


<div class="markdown"><p>Here we needed to know that the oracle returned the score 31 from the guess &quot;arise&quot;. We could instead write the function with the oracle as an argument and evaluate the score on which to filter within the <code>refine</code> function.</p>
<p>In Julia we can define several methods for any function name as long as we can distinguish the &quot;signature&quot; of the argument. This is why every time we define a new function, the response says it is a <code>&#40;generic function with 1 method&#41;</code>.</p>
<p>We define another <code>refine</code> method which takes a <code>Function</code> as the third argument</p>
</div>

<pre class='language-julia'><code class='language-julia'>refine(pool, guess, oracle::Function) = refine(pool, guess, oracle(guess))</code></pre>
<pre id='var-refine' class='pre-class'><code class='code-output'>refine (generic function with 2 methods)</code></pre>


<div class="markdown"><p>This definition uses the short-cut, &quot;one-liner&quot;, form of Julia function definition.</p>
<p>Here we define one method as an application of another method with the arguments rearranged a bit. This is a common idiom in Julia.</p>
<p>We can check that there are indeed two method definitions.</p>
</div>

<pre class='language-julia'><code class='language-julia'>methods(refine)</code></pre>
# 2 methods for generic function <b>refine</b>:<ul><li> refine(pool, guess, oracle::<b>Function</b>) in Main.workspace#3 at <a href="https://github.com/dmbates/Wordlebase3/tree/250f1182818757f69c43a57ae20a69488a09780d//tutorials/Wordlebase3.jl#==#a4e60664-0f16-4f9a-9ddd-7430abf8989d#L1" target="_blank">/home/runner/work/Wordlebase3/Wordlebase3/tutorials/Wordlebase3.jl#==#a4e60664-0f16-4f9a-9ddd-7430abf8989d:1</a></li> <li> refine(pool, guess, sc) in Main.workspace#3 at <a href="https://github.com/dmbates/Wordlebase3/tree/250f1182818757f69c43a57ae20a69488a09780d//tutorials/Wordlebase3.jl#==#949c440c-dda0-49d9-abaa-7c3835eedc41#L1" target="_blank">/home/runner/work/Wordlebase3/Wordlebase3/tutorials/Wordlebase3.jl#==#949c440c-dda0-49d9-abaa-7c3835eedc41:1</a></li> </ul>


<div class="markdown"><p>&#40;the messy descriptions of where the methods were defined is because we&#39;re doing this in a notebook&#41; and that the second method works as intended</p>
</div>

<pre class='language-julia'><code class='language-julia'>refine(wordlestrings, "arise", oracle196)</code></pre>
<pre id='var-hash135434' class='documenter-example-output'><code class='code-output'>["ester", "loser", "poser", "rebus", "reset", "screw", "serum", "sever", "sewer", "sheer", "shrew", "sneer", "sober", "sower", "sperm", "steer", "stern", "super", "surer", "usher"]</code></pre>


<div class="markdown"><p>Now we need to choose another guess. In the sample game, the second guess was &quot;route&quot;.  Interestingly this word is not in the set of possible targets.</p>
</div>

<pre class='language-julia'><code class='language-julia'>"route" ∈ pool1</code></pre>
<pre id='var-hash698131' class='pre-class'><code class='code-output'>false</code></pre>


<div class="markdown"><p>Choosing a word, or even a non-word, that can&#39;t be a target is allowed, and there is some potential for it being useful as a way of screening the possible targets. But generally it is not a great strategy to waste a guess that can&#39;t be the target, especially when only six guesses are allowed. In our strategy described below we always choose our guesses from the pool. This is known as <a href="https://www.techradar.com/news/wordle-hard-mode">hard mode</a> in Wordle, although, from the programmer&#39;s point of view it&#39;s more like &quot;easy mode&quot;.</p>
<p>Anyway, continuing with the sample game</p>
</div>

<pre class='language-julia'><code class='language-julia'>pool2 = refine(pool1, "route", oracle196)</code></pre>
<pre id='var-pool2' class='documenter-example-output'><code class='code-output'>["rebus"]</code></pre>


<div class="markdown"><p>So we&#39;re done - the target word must be &quot;rebus&quot; and the third guess, &quot;rules&quot;, in the sample game is redundant.</p>
<h2>Choosing a good guess</h2>
<p>Assuming that we will choose our next guess from the current target pool, how should we go about it? We want a guess that will reduce the size of the target pool as much as possible, but we don&#39;t know what that reduction will be until we have submitted the guess to the oracle.</p>
<p>However, we can set this up as a probability problem. If the target has been randomly chosen from the set of possible targets, which apparently they are, and our pool size is currently <code>n</code>, then each word in the pool has probability <code>1/n</code> of being the target. Thus we can evaluate the expected size of the set of possible targets after the next turn for each potential guess, and choose the guess that gives the smallest expected size.</p>
<p>It sounds as if it is going to be difficult to evaluate the expected pool size because we need to loop over every word in the pool as a guess and, for that guess, every word in the pool as a target, evaluate the score and do something with that score. But it turns out that all we need to know for each potential guess is the number of words in the pool that would give each of the possible scores. We need a loop within a loop but all the inner loop has to do is evaluate a score and increment some counts.</p>
<p>In mathematical terms, each guess partitions the targets in the current pool into at most 243 <a href="https://en.wikipedia.org/wiki/Equivalence_class">equivalence classes</a> according to the score from the guess on that target.</p>
<p>The key point here is that the number of words in a given class is both the size of the pool that would result from one of these targets and the number of targets that could give this pool.</p>
<p>Let&#39;s start by evaluating the counts of the words in the pool that give each possible score from a given guess. We will start with a vector of 243 zeros and, for every word in the pool, evaluate the score and increment the count for that score.</p>
<p>We should make a quick detour to discuss a couple of technical points about Julia programming. In Julia, by default, the indices into an array start at 1, so the position we will increment in the array of sizes is at <code>score&#40;guess, w&#41; &#43; 1</code>. Secondly, instead of allocating an array for the result within the function we will pass the container - a vector of integers of length 243 - as an argument and modify its contents within the function.</p>
<p>There are two reasons we may want to pass the count vector into the function. First, if this function is to be called many times, we don&#39;t want to allocate storage for the result within the function if we can avoid it. Second, for generality, we want to avoid assuming that the number of classes will always be 243. If we allocate the storage outside the function then we don&#39;t have to build assumptions on its size into the function.</p>
<p>By convention, such &quot;mutating&quot; functions that can change the contents of arguments are given names that end in <code>&#33;</code>, as a warning to users that calling the function may change the contents of one or more arguments. This is just a convention - the <code>&#33;</code> doesn&#39;t affect the semantics in any way.</p>
<p>Declare the array of bin sizes</p>
</div>

<pre class='language-julia'><code class='language-julia'>sizes = zeros(Int, 243)</code></pre>
<pre id='var-sizes' class='documenter-example-output'><code class='code-output'>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, more, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]</code></pre>


<div class="markdown"><p>and the function to evaluate the bin sizes</p>
</div>

<pre class='language-julia'><code class='language-julia'>function binsizes!(sizes, words, guess)
	fill!(sizes, 0)    # zero out the counts
	for w in words
		sizes[score(guess, w) + 1] += 1
	end
	return sizes
end</code></pre>
<pre id='var-binsizes!' class='pre-class'><code class='code-output'>binsizes! (generic function with 1 method)</code></pre>


<div class="markdown"><p>For the first guess, &quot;arise&quot;, on the original set <code>words</code>, this gives</p>
</div>

<pre class='language-julia'><code class='language-julia'>binsizes!(sizes, wordlestrings, "arise")</code></pre>
<pre id='var-hash647599' class='documenter-example-output'><code class='code-output'>[168, 121, 61, 80, 41, 17, 17, 9, 20, 107, 35, 25, 21, 4, 5, 6, 0, 0, 51, 15, more, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]</code></pre>


<div class="markdown"><p>Recall that each of these sizes is both the size the pool and the number of targets that would return this pool. That is, there are 168 targets that would return a score of 0 from this guess and the size of the pool after refining by this guess and a score of 0 would be 168.</p>
<p>Thus, the expected pool size after a first guess of &quot;arise&quot; is the sum of the squared bin sizes divided by the sum of the sizes, which is the current pool size.</p>
<p>For the example of the first guess <code>&quot;arise&quot;</code> and the original pool, <code>words</code>, the expected pool size after refining by the score for this guess is</p>
</div>

<pre class='language-julia'><code class='language-julia'>sum(abs2, sizes) / sum(sizes)</code></pre>
<pre id='var-hash333467' class='pre-class'><code class='code-output'>63.72570194384449</code></pre>


<div class="markdown"><p>This is remarkable. We start off with a pool of 2315 possible targets and, with a single guess, will, on average, refining that pool to around 64 possible targets.</p>
</div>


<div class="markdown"><h2>Optimal guesses at each stage</h2>
<p>We now have the tools in place to determine the guess that will produce the smallest expected pool size from a set of possible targets. First we will create an <code>expectedsize&#33;</code> function that just calls <code>binsizes&#33;</code> then returns the expected size. This will be used in an anonymous function passed to <code>argmin</code>.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function expectedsize!(sizes, words, guess)
	binsizes!(sizes, words, guess)
	return sum(abs2, sizes) / length(words)
end</code></pre>
<pre id='var-expectedsize!' class='pre-class'><code class='code-output'>expectedsize! (generic function with 1 method)</code></pre>


<div class="markdown"><p>The word chosen for the first guess in the sample game, &quot;arise&quot;, is a good choice.</p>
</div>

<pre class='language-julia'><code class='language-julia'>expectedsize!(sizes, wordlestrings, "arise")</code></pre>
<pre id='var-hash457964' class='pre-class'><code class='code-output'>63.72570194384449</code></pre>


<div class="markdown"><p>but not the best choice.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function bestguess!(sizes, words)
	return argmin(w -&gt; expectedsize!(sizes, words, w), words)
end</code></pre>
<pre id='var-bestguess!' class='pre-class'><code class='code-output'>bestguess! (generic function with 1 method)</code></pre>

<pre class='language-julia'><code class='language-julia'>bestguess!(sizes, wordlestrings)</code></pre>
<pre id='var-hash158156' class='pre-class'><code class='code-output'>"raise"</code></pre>

<pre class='language-julia'><code class='language-julia'>expectedsize!(sizes, wordlestrings, "raise")</code></pre>
<pre id='var-hash478329' class='pre-class'><code class='code-output'>61.00086393088553</code></pre>


<div class="markdown"><p>That is, the optimal first guess in Wordle &quot;hard mode&quot; is &quot;raise&quot;. &#40;A slight variation of this task of choosing the best initial choice was the example in the discourse thread mentioned above.&#41;</p>
<p>To continue playing.</p>
</div>

<pre class='language-julia'><code class='language-julia'>guess2 = bestguess!(sizes, refine(wordlestrings, "raise", oracle196))</code></pre>
<pre id='var-guess2' class='pre-class'><code class='code-output'>"rebus"</code></pre>

<pre class='language-julia'><code class='language-julia'>oracle196("rebus")</code></pre>
<pre id='var-hash391510' class='pre-class'><code class='code-output'>242</code></pre>


<div class="markdown"><p>And we are done after 2 guesses.</p>
<p>To write a function that plays a game of Wordle, we pass an oracle function and the initial target pool.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function playgame(oracle::Function, pool)
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
end</code></pre>
<pre id='var-playgame' class='pre-class'><code class='code-output'>playgame (generic function with 1 method)</code></pre>

<pre class='language-julia'><code class='language-julia'>results = playgame(oracle196, wordlestrings)</code></pre>
<table>
<tr>
<th>guess</th>
<th>score</th>
<th>pool_size</th>
</tr>
<tr>
<td>"raise"</td>
<td>"🟩🟫🟫🟨🟨"</td>
<td>2315</td>
</tr>
<tr>
<td>"rebus"</td>
<td>"🟩🟩🟩🟩🟩"</td>
<td>2</td>
</tr>
</table>



<div class="markdown"><p>If we define another <code>playgame</code> method that takes a random number generator and a target pool, we can play a game with the target chosen at random.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function playgame(rng::AbstractRNG, pool)
	return playgame(Base.Fix2(score, rand(rng, pool)), pool)
end</code></pre>
<pre id='var-playgame' class='pre-class'><code class='code-output'>playgame (generic function with 2 methods)</code></pre>


<div class="markdown"><p>First, initialize a random number generator &#40;RNG&#41; for reproducibility with this notebook.</p>
<p>As of Julia v1.7.0 the default RNG is <code>Xoshiro</code></p>
</div>

<pre class='language-julia'><code class='language-julia'>rng = Xoshiro(42);</code></pre>


<pre class='language-julia'><code class='language-julia'>playgame(rng, wordlestrings)</code></pre>
<table>
<tr>
<th>guess</th>
<th>score</th>
<th>pool_size</th>
</tr>
<tr>
<td>"raise"</td>
<td>"🟫🟫🟫🟩🟩"</td>
<td>2315</td>
</tr>
<tr>
<td>"loose"</td>
<td>"🟫🟩🟨🟩🟩"</td>
<td>20</td>
</tr>
<tr>
<td>"copse"</td>
<td>"🟫🟩🟨🟩🟩"</td>
<td>4</td>
</tr>
<tr>
<td>"posse"</td>
<td>"🟩🟩🟩🟩🟩"</td>
<td>1</td>
</tr>
</table>



<div class="markdown"><p>None of the functions we have defined are restricted to the Wordle list or the representation of these words as <code>String</code>.</p>
</div>

<pre class='language-julia'><code class='language-julia'>playgame(rng, wordlechartuples)</code></pre>
<table>
<tr>
<th>guess</th>
<th>score</th>
<th>pool_size</th>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'r'", MIME type text/plain)), (2, ("'a'", MIME type text/plain)), (3, ("'i'", MIME type text/plain)), (4, ("'s'", MIME type text/plain)), (5, ("'e'", MIME type text/plain))], :type => :Tuple, :objectid => "d36320a6c9023161")</td>
<td>"🟫🟫🟨🟫🟫"</td>
<td>2315</td>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'p'", MIME type text/plain)), (2, ("'i'", MIME type text/plain)), (3, ("'l'", MIME type text/plain)), (4, ("'o'", MIME type text/plain)), (5, ("'t'", MIME type text/plain))], :type => :Tuple, :objectid => "8b4f1973749a357c")</td>
<td>"🟫🟨🟫🟨🟫"</td>
<td>107</td>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'c'", MIME type text/plain)), (2, ("'o'", MIME type text/plain)), (3, ("'m'", MIME type text/plain)), (4, ("'i'", MIME type text/plain)), (5, ("'c'", MIME type text/plain))], :type => :Tuple, :objectid => "bd9e9550f74e15be")</td>
<td>"🟨🟩🟫🟩🟩"</td>
<td>4</td>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'i'", MIME type text/plain)), (2, ("'o'", MIME type text/plain)), (3, ("'n'", MIME type text/plain)), (4, ("'i'", MIME type text/plain)), (5, ("'c'", MIME type text/plain))], :type => :Tuple, :objectid => "8e2bc7c4329bf223")</td>
<td>"🟩🟩🟩🟩🟩"</td>
<td>1</td>
</tr>
</table>


<pre class='language-julia'><code class='language-julia'>playgame(rng, primelchartuples)</code></pre>
<table>
<tr>
<th>guess</th>
<th>score</th>
<th>pool_size</th>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'0'", MIME type text/plain)), (2, ("'7'", MIME type text/plain)), (3, ("'1'", MIME type text/plain)), (4, ("'9'", MIME type text/plain)), (5, ("'3'", MIME type text/plain))], :type => :Tuple, :objectid => "5ecd64b54d8a610")</td>
<td>"🟨🟨🟨🟫🟫"</td>
<td>9592</td>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'1'", MIME type text/plain)), (2, ("'4'", MIME type text/plain)), (3, ("'0'", MIME type text/plain)), (4, ("'8'", MIME type text/plain)), (5, ("'7'", MIME type text/plain))], :type => :Tuple, :objectid => "24571a3093946ec7")</td>
<td>"🟨🟩🟩🟫🟩"</td>
<td>142</td>
</tr>
<tr>
<td>Dict{Symbol, Any}(:elements => [(1, ("'4'", MIME type text/plain)), (2, ("'4'", MIME type text/plain)), (3, ("'0'", MIME type text/plain)), (4, ("'1'", MIME type text/plain)), (5, ("'7'", MIME type text/plain))], :type => :Tuple, :objectid => "11feeba5898f4f86")</td>
<td>"🟩🟩🟩🟩🟩"</td>
<td>2</td>
</tr>
</table>



<div class="markdown"><p>We can even use <code>playgame</code> to play all possible Wordle games and check properties of our strategy for choosing the next guess. For example, are we guaranteed to complete the game in six or fewer guesses? What is the average number of guesses to complete the game?</p>
<p>And we may want to consider alternative storage schemes for the original pool. How do they influence run-time of the game?</p>
<p>But before doing this we should address a glaring inefficiency in the existing <code>playgame</code> methods: the initial guess only depends on the <code>pool</code> argument and we keep evaluating the same answer at the beginning of every game. Of all the calls to <code>bestguess</code> in the game this is the most expensive call because the pool is largest at the beginning of play.</p>
<h2>Combining the pool and the initial guess</h2>
<p>To ensure that the initial guess is the one generated by the pool we should store them as parts of a single structure. And while we are at it, we can also create and store the vector to accumulate the bin sizes and we can do a bit of error checking.</p>
<p>We declare the type</p>
</div>

<pre class='language-julia'><code class='language-julia'>struct GamePool{T}    # T will be the element type of the pool
	pool::Vector{T}
	initial::T
	sizes::Vector{Int}
end</code></pre>



<div class="markdown"><p>and an external constructor for the type. Generally the external constructor would have the same name as the type but that is not allowed in Pluto notebooks so we use a lower-case name.</p>
</div>

<pre class='language-julia'><code class='language-julia'>function gamepool(pool::Vector{T}) where {T}
	elsz = length(first(pool))
	if !all(==(elsz), length.(pool))
		throw(ArgumentError("lengths of elements of pool are not consistent"))
	end
	sizes = zeros(Int, 3 ^ elsz)
	GamePool(pool, bestguess!(sizes, pool), sizes)
end</code></pre>
<pre id='var-gamepool' class='pre-class'><code class='code-output'>gamepool (generic function with 1 method)</code></pre>

<pre class='language-julia'><code class='language-julia'>wordlestrgp = gamepool(wordlestrings)</code></pre>
<pre id='var-wordlestrgp' class='documenter-example-output'><code class='code-output'>GamePool{SubString{String}}(["aback", "abase", "abate", "abbey", "abbot", "abhor", "abide", "abled", "abode", more, "zonal"], "raise", [446, 169, 43, 329, 123, 25, 58, 19, 28, more, 1])</code></pre>


<div class="markdown"><p>We can now define a <code>fastgame</code> generic and some methods</p>
</div>

<pre class='language-julia'><code class='language-julia'>function fastgame(oracle::Function, gp::GamePool)
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
end</code></pre>
<pre id='var-fastgame' class='pre-class'><code class='code-output'>fastgame (generic function with 1 method)</code></pre>

<pre class='language-julia'><code class='language-julia'>function fastgame(rng::AbstractRNG, gp::GamePool)
	fastgame(Base.Fix2(score, rand(rng, gp.pool)), gp)
end</code></pre>
<pre id='var-fastgame' class='pre-class'><code class='code-output'>fastgame (generic function with 2 methods)</code></pre>

<pre class='language-julia'><code class='language-julia'>fastgame(gp::GamePool) = fastgame(Random.GLOBAL_RNG, gp)</code></pre>
<pre id='var-fastgame' class='pre-class'><code class='code-output'>fastgame (generic function with 3 methods)</code></pre>

<pre class='language-julia'><code class='language-julia'>fastgame(wordlestrgp)</code></pre>
<table>
<tr>
<th>guess</th>
<th>score</th>
<th>pool_size</th>
</tr>
<tr>
<td>"raise"</td>
<td>"🟫🟨🟫🟩🟩"</td>
<td>2315</td>
</tr>
<tr>
<td>"cease"</td>
<td>"🟫🟩🟩🟩🟩"</td>
<td>8</td>
</tr>
<tr>
<td>"lease"</td>
<td>"🟩🟩🟩🟩🟩"</td>
<td>2</td>
</tr>
</table>



<div class="markdown"><p>If you want to play on the Wordle web site you would need to create an oracle function that somehow entered the guess and converted the tile pattern to a numeric score.</p>
<p>But I don&#39;t think it would be very interesting and it would certainly spoil the fun of playing Wordle.</p>
<p>So instead of doing that, let&#39;s see what this tells us about the Art of Julia Programming.</p>
</div>


<div class="markdown"><h2>Examining the <code>score</code> function</h2>
<p>In the Sherlock Holmes story <a href="thttps://en.wikipedia.org/wiki/The_Adventure_of_Silver_Blaze">The Adventure of Silver Blaze</a> there is a famous exchange where Holmes remarks on &quot;the curious incident of the dog in the night-time&quot; &#40;see the link&#41;. The critical clue in the case is not what happened but what didn&#39;t happen - the dog didn&#39;t bark.</p>
<p>Just as Holmes found it interesting that the dog didn&#39;t bark, we should find the functions in this notebook interesting for what they don&#39;t include. For the most part the arguments aren&#39;t given explicit types.</p>
<p>Knowing the concrete types of arguments is very important when compiling functions, as is done in Julia, but these functions are written without explicit types.</p>
<p>Consider the <code>score</code> function which we reproduce here</p>
<pre><code class="language-jl">function score&#40;guess, target&#41;
    s &#61; 0
    for &#40;g, t&#41; in zip&#40;guess, target&#41;
        s *&#61; 3
        s &#43;&#61; &#40;g &#61;&#61; t ? 2 : Int&#40;g ∈ target&#41;&#41;
    end
    return s
end</code></pre>
<p>The arguments to <code>score</code> can be any type. In fact, formally they are of an abstract type called <code>Any</code>.</p>
<p>So how do we make sure that the actual arguments make sense for this function? Well, the first thing that is done with the arguments is to pass them to <code>zip&#40;guess, target&#41;</code> to produce pairs of values, <code>g</code> and <code>t</code>, that can be compared for equality, <code>g &#61;&#61; t</code>. In a sense <code>score</code> delegates the task of checking that the arguments are sensible to the <code>zip</code> function.</p>
<p>For those unfamiliar with zipping two or more iterators, we can check what the result is.</p>
</div>

<pre class='language-julia'><code class='language-julia'>collect(zip("arise", "rebus"))</code></pre>
<pre id='var-hash198416' class='documenter-example-output'><code class='code-output'>[('a', 'r'), ('r', 'e'), ('i', 'b'), ('s', 'u'), ('e', 's')]</code></pre>


<div class="markdown"><p>One of the great advantages of dynamically-typed languages with a REPL &#40;read-eval-print-loop&#41; like Julia is that we can easily check what <code>zip</code> produces in a couple of examples &#40;or even read the documentation returned by <code>?zip</code>, if we are desperate&#41;.</p>
<p>The rest of the function is a common pattern - initialize <code>s</code>, which will be the result, modify <code>s</code> in a loop, and return it. The Julia expression</p>
<pre><code class="language-jl">s *&#61; 3</code></pre>
<p>indicates, as in several other languages, that <code>s</code> is to be multiplied by 3 in-place.</p>
<p>An expression like</p>
<pre><code class="language-jl">g &#61;&#61; t ? 2 : Int&#40;g  ∈ target&#41;</code></pre>
<p>is a <em>ternary operator</em> expression &#40;the name comes from the operator taking three arguments&#41;. It evaluates the condition, <code>g &#61;&#61; t</code>, and returns <code>2</code> if the condition is <code>true</code>. If the <code>g &#61;&#61; t</code> is <code>false</code> the operator returns the value of the Boolean expression <code>g  ∈ target</code>, converted to an <code>Int</code>. The Boolean expression will return <code>false</code> or <code>true</code>, which become <code>0</code> or <code>1</code> when converted to an <code>Int</code>. This is one of the few times that we explicitly convert a result to a particular type. We do so because <code>2</code> is an <code>Int</code> and we don&#39;t want the type of the value of the ternary operator expression to change depending on the value of its arguments.</p>
<p>The operation of multiplying by 3 and adding 2 or 1 or 0 is an implementation of <a href="https://en.wikipedia.org/wiki/Horner&#37;27s_method">Horner&#39;s method</a> for evaluating a polynomial.</p>
<p>The function is remarkable because it is both general and compact. Even more remarkable is that it will be very, very fast after its first usage triggers compilation. That&#39;s important because this function will be in a &quot;hot loop&quot;. It will be called many, many times when evaluating the next guess.</p>
<p>We won&#39;t go into detail about the Julia compiler except to note that compilation is performed for specific <em>method signatures</em> not for general method definitions.</p>
<p>There are several functions and macros in Julia that allow for inspection at different stages of compilation. One of the most useful is the macro <code>@code_warntype</code> which is used to check for situations where type inference has not been successful. Applying it as</p>
<pre><code class="language-jl">@code_warntype score&#40;&quot;arise&quot;, &quot;rebus&quot;&#41;</code></pre>
<p>will show the type inference is based on concrete types &#40;<code>String</code>&#41; for the arguments.</p>
<p>Some argument types are handled more efficiently than others. Without going in to details we note that we can take advantage of the fact that we have exactly 5 characters and convert the elements of <code>words</code> from <code>String</code> to <code>NTuple&#123;5,Char&#125;</code>, which is an ordered, fixed-length homogeneous collection.</p>
<p>Using the <code>@benchmark</code> macro from the <code>BenchmarkTools</code> package gives run times of a few tens of nanoseconds for these arguments, and shows that the function applied to the fixed-length collections is faster.</p>
</div>


<div class="markdown"><p>That is, the version using the fixed-length structure is nearly 4 times as fast as that using the variable-length <code>String</code> structure. &#40;For those familiar with what the &quot;stack&quot; and the &quot;heap&quot; are, the main advantage of an <code>NTuple</code> is that it can be passed on the stack whereas a <code>String</code> must be heap allocated.&#41;</p>
<p>The details aren&#39;t as important as the fact that we can exert a high level of control and optimization of very general code and we can test and benchmark the code interactively.</p>
<p>In fact the whole collection of functions can work with <code>NTuple</code> representations of the words. First convert <code>words</code> to a vector of tuples</p>
</div>


<div class="markdown"><p>&#40;Note that for conversion of a single length-5 string the call was <code>NTuple&#123;5,Char&#125;&#40;&quot;rebus&quot;&#41;</code> but for conversion of a vector of length-5 strings the call includes a dot before the opening parenthesis. This is an example of &quot;dot-broadcasting&quot;, which is a very powerful way in Julia of broadcasting scalar functions to arrays or other iterators.</p>
<p>Then we can just pass the result to <code>playWordle</code>.</p>
</div>


<div class="markdown"><p>We can benchmark both versions to see if the speed advantage for tuples carries over to the higher-level calculation. However we want to make sure that it is an apples-to-apples comparison so we first select the index of the target then create the oracle from that element of the <code>words</code> or the <code>tuples</code> vector.</p>
</div>


<div class="markdown"><p>Now there is a speedup of more than a factor of 10 for using tuples.</p>
<p>Of course, there is a glaring inefficiency in the <code>playWordle</code> function in that the first guess, <code>&quot;raise&quot;</code>, is being recalculated for every game. We should allow this fixed first guess to be passed as an argument.</p>
<p>While we are revising the function we can clean up a few other places where assumptions on the length of the words is embedded and do some checking of arguments.</p>
</div>
<div class='manifest-versions'>
<p>Built with Julia 1.7.1 and</p>
DataFrames 1.3.2<br>
PlutoUI 0.7.34<br>
Primes 0.5.1
</div>

<!-- PlutoStaticHTML.End -->
~~~