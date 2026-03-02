Code.require_file("tokenizer.exs", __DIR__)

[f|_] = System.argv()
{:ok, s} = File.read(f)
IO.inspect(Tokenizer.tokenize(s))
