Code.require_file("tokenizer.exs", __DIR__)
Code.require_file("parser.exs", __DIR__)
Code.require_file("interpreter.exs", __DIR__)

[f|_] = System.argv()
{:ok, s} = File.read(f)
tokens = Tokenizer.tokenize(s)
ast = Parser.parse(tokens)
Interpreter.run(ast)
