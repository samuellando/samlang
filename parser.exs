defmodule Program do
  defstruct statements: [] 
end

defmodule Expression do
  defstruct a: nil, b: nil, op: nil
end

defmodule Assignment do
  defstruct identifier: %Token{type: :identifier}, expression: %Expression{}
end

defmodule If do
  defstruct condition: %Expression{}, statements: [], elseStatements: []
end

defmodule While do
  defstruct condition: %Expression{}, statements: []
end

defmodule Func do
  defstruct identifier: %Token{type: :identifier}, parameters: [], statements: []
end

defmodule Call do
  defstruct identifier: %Token{type: :identifier}, arguments: []
end

defmodule Return do
  defstruct expression: %Expression{}
end


defmodule Parser do
  def parse(l) do
    p = _parse(l)
    %Program{statements: p}
  end

  defp _parse([]) do
    []
  end
  defp _parse(l) do
    {s, rest} = parse_statement(l)
    [s|_parse(rest)]
  end

  defp parse_statement([]) do
    {nil, []}
  end
  defp parse_statement(l = [_|rest]) do
    case l do
      [%Token{type: :newLine}|_] -> {nil, rest}
      [%Token{type: :keyword, value: "func"}|_] -> parse_func(l)
      [%Token{type: :keyword, value: "while"}|_] -> parse_while(l)
      [%Token{type: :keyword, value: "if"}|_] -> parse_if(l)
      [%Token{type: :keyword, value: "return"}|_] -> parse_return(l)
      [%Token{type: :identifier}, %Token{type: :assign}|_] -> parse_assignment(l)
      [%Token{type: :identifier}, %Token{type: :openPar}|_] -> parse_function_call(l)
      _ -> raise "Unexpected token #{hd(l)}"
    end
  end

  defp parse_assignment([id, %Token{type: :assign}|rest]) do
    try do
      {exp, rest} = parse_expression(rest)
      {%Assignment{identifier: id, expression: exp}, rest}
    catch 
      err -> raise "Failed to parse Assignment #{id} #{err}"
    end
  end
  defp parse_assignment([t|_]) do
    raise "Assignments should be of the form: identifier = expression: #{t}"
  end

  defp parse_expression(l) do
    case parse_operand(l) do
      {a, rest} when a != nil -> case rest do 
        [%Token{type: :newLine}|rest] -> {%Expression{a: a}, rest}
        [%Token{type: :openCurly}|_] -> {%Expression{a: a}, rest}
        [%Token{type: :closeCurly}|_] -> {%Expression{a: a}, rest}
        [%Token{type: :closePar}|_] -> {%Expression{a: a}, rest}
        [%Token{type: :coma}|_] -> {%Expression{a: a}, rest}
        [] -> {a, rest}
        _ -> case parse_operator(rest) do
          {op, rest} when op != nil -> 
            {b, rest} = parse_expression(rest)
            {%Expression{a: a, b: b, op: op}, rest}
          _ -> raise "Unexpected #{hd(rest)}"
          end
        end
      _ -> case l do
        [t = %Token{type: :openPar}|rest] -> case parse_expression(rest) do
          {ex, rest} -> case rest do
            [%Token{type: :closePar}|rest] -> case rest do
              [%Token{type: :newLine}|rest] -> {ex, rest}
              [%Token{type: :closeCurly}|_] -> {ex, rest}
              [%Token{type: :openCurly}|_] -> {ex, rest}
              [%Token{type: :closePar}|_] -> {ex, rest}
              [%Token{type: :coma}|_] -> {ex, rest}
              [] -> {ex, rest}
              _ -> case parse_operator(rest) do
                {op, rest} when op != nil -> 
                  {b, rest} = parse_expression(rest)
                  {%Expression{a: ex, b: b, op: op}, rest}
                _ -> 
                  [t|_] = rest
                  raise "Unexpected #{t}"
                end
              end
            _ -> raise "Missing matching parenthesis for #{t}"
          end
        end
        _ -> raise "Expected at least one operand in expression #{hd(l)}"
      end
    end
  end

  defp parse_operand([]) do
    {nil, []}
  end
  defp parse_operand(l) do
    case parse_function_call(l) do
      {nil, rest} -> case l do
        [t = %Token{type: :number}|rest] -> {String.to_integer(t.value), rest}
        [t = %Token{type: :string}|rest] -> {t.value, rest}
        [%Token{type: :keyword, value: "true"}|rest] -> {true, rest}
        [%Token{type: :keyword, value: "false"}|rest] -> {false, rest}
        [t = %Token{type: :identifier}|rest] -> {t, rest}
        _ -> {nil, rest}
      end
      {c, rest} -> {c, rest}
    end
  end

  defp parse_function_call(l = [id = %Token{type: :identifier}|rest]) do
    case parse_arguments(rest) do
      {nil, _} -> {nil, l}
      {args, rest} -> {%Call{identifier: id, arguments: args}, rest}
    end

  end
  defp parse_function_call(l) do
    {nil, l}
  end

  defp parse_operator([]) do
    {nil, []}
  end
  defp parse_operator([t|rest]) do
    case t do
      %Token{type: :add} -> {t, rest}
      %Token{type: :sub} -> {t, rest}
      %Token{type: :div} -> {t, rest}
      %Token{type: :mul} -> {t, rest}
      %Token{type: :equal} -> {t, rest}
      %Token{type: :greater} -> {t, rest}
      %Token{type: :less} -> {t, rest}
      %Token{type: :ge} -> {t, rest}
      %Token{type: :le} -> {t, rest}
      _ -> {nil, rest}
    end
  end

  defp parse_func([_, id = %Token{type: :identifier}|rest]) do
    {params, rest} = parse_parameters(rest)
    {block, rest} = parse_block(rest)
    {%Func{identifier: id, parameters: params, statements: block}, rest}
  end

  defp parse_parameters([t = %Token{type: :openPar}|rest]) do
    try do
      _parse_parameters(rest)
    catch
      err -> raise "Failed to parse parameter list #{t} #{err}"
    end
  end
  defp parse_parameters([t|_]) do
    raise "Expected open parenthesis #{t}"
  end
  defp _parse_parameters([p = %Token{type: :identifier}, %Token{type: :coma}|rest]) do
    {params, rest} = _parse_parameters(rest)
    {[p|params], rest}
  end
  defp _parse_parameters([p = %Token{type: :identifier}, %Token{type: :closePar}|rest]) do
    {[p], rest}
  end
  defp _parse_parameters(_) do 
    raise "expected <identifier><coma> or <identifier><closeParenthesis> in argument list"
  end

  defp parse_arguments([t = %Token{type: :openPar}|rest]) do
    try do
      _parse_arguments(rest)
    catch
      err -> raise "Failed to parse argument list #{t} #{err}"
    end
  end
  defp parse_arguments(l) do
    {nil,l}
  end
  defp _parse_arguments([%Token{type: :closePar}|rest]) do
    {[], rest}
  end
  defp _parse_arguments(l) do
    {exp, rest} = parse_expression(l)
    {args, rest} = _parse_arguments(rest)
    {[exp|args], rest}
  end

  defp parse_if([_|rest]) do
    {cond, rest} = parse_expression(rest)
    {block, rest} = parse_block(rest)
    case rest do
      [%Token{type: :keyword, value: "else"}|rest] -> 
        {elseBlock, rest} = parse_block(rest)
        {%If{condition: cond, statements: block, elseStatements: elseBlock}, rest}
      _ -> {%If{condition: cond, statements: block}, rest}
    end
  end

  defp parse_while([_|rest]) do
    {cond, rest} = parse_expression(rest)
    {block, rest} = parse_block(rest)
    {%While{condition: cond, statements: block}, rest}
  end

  defp parse_block([%Token{type: :openCurly}|rest]) do
    _parse_block(rest)
  end
  defp parse_block([t|_]) do
    raise "Expected '{' got #{t}"
  end
  defp _parse_block([%Token{type: :closeCurly}|rest]) do
    {[], rest}
  end
  defp _parse_block([]) do
    raise "Expected '}' go EOF"
  end
  defp _parse_block(l) do
    {s, rest} = parse_statement(l)
    {b, rest} = _parse_block(rest)
    {[s|b], rest}
  end

  defp parse_return([_|rest]) do
    {exp, rest} = parse_expression(rest)
    {%Return{expression: exp}, rest}
  end
end

