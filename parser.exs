defmodule Program do
  defstruct statements: [] 
end

defmodule Expression do
  defstruct a: nil, b: nil, op: nil
end

defmodule Assignment do
  defstruct identifier: %Token{type: :identifier}, expression: %Expression{}
end

defmodule Allocation do
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
  defstruct arguments: []
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
      [%Token{type: :identifier}, %Token{type: :alloc}|_] -> parse_allocation(l)
      _ -> case parse_expression(l) do
        {nil, [t|_]} -> raise "Unexpected token #{t}"
        {s, rest} -> {s, rest}
      end
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

  defp parse_allocation([id, %Token{type: :alloc}|rest]) do
    try do
      {exp, rest} = parse_expression(rest)
      {%Allocation{identifier: id, expression: exp}, rest}
    catch 
      err -> raise "Failed to parse Allocation #{id} #{err}"
    end
  end
  defp parse_allocation([t|_]) do
    raise "Allocations should be of the form: identifier = expression: #{t}"
  end

  def parse_expression(l = [t|_]) do
    case parse_equality(l) do
      {nil, _} -> raise "Expected an expression #{t}"
      {exp, rest} -> {exp, rest}
    end
  end

  defp parse_equality(l) do
    case parse_comparison(l) do
      {nil, rest} -> {nil, rest}
      {a, rest} -> case parse_equality_op(rest) do
        {nil, rest} -> {a, rest}
        {op, rest} -> case parse_comparison(rest) do
          {nil, _} -> raise "Expected expression after #{op}"
          {b, rest} -> {%Expression{a: a, b: b, op: op}, rest}
        end
      end
    end
  end

  defp parse_equality_op(l = [t|rest]) do 
    case t do
      %Token{type: :equal} -> {t, rest}
      %Token{type: :notEqual} -> {t, rest}
      _ -> {nil, l}
    end
  end

  defp parse_comparison(l) do
    case parse_term(l) do
      {nil, rest} -> {nil, rest}
      {a, rest} -> case parse_comparison_op(rest) do
        {nil, rest} -> {a, rest}
        {op, rest} -> case parse_term(rest) do
          {nil, _} -> raise "Expected expression after #{op}"
          {b, rest} -> {%Expression{a: a, b: b, op: op}, rest}
        end
      end
    end
  end

  defp parse_comparison_op(l = [t|rest]) do 
    case t do
      %Token{type: :less} -> {t, rest}
      %Token{type: :greater} -> {t, rest}
      %Token{type: :ge} -> {t, rest}
      %Token{type: :le} -> {t, rest}
      _ -> {nil, l}
    end
  end

  defp parse_term(l) do
    case parse_factor(l) do
      {nil, rest} -> {nil, rest}
      {a, rest} -> case parse_term_op(rest) do
        {nil, rest} -> {a, rest}
        {op, rest} -> case parse_factor(rest) do
          {nil, _} -> raise "Expected expression after #{op}"
          {b, rest} -> {%Expression{a: a, b: b, op: op}, rest}
        end
      end
    end
  end

  defp parse_term_op(l = [t|rest]) do 
    case t do
      %Token{type: :add} -> {t, rest}
      %Token{type: :sub} -> {t, rest}
      _ -> {nil, l}
    end
  end

  defp parse_factor(l) do
    case parse_unary(l) do
      {nil, rest} -> {nil, rest}
      {a, rest} -> case parse_factor_op(rest) do
        {nil, rest} -> {a, rest}
        {op, rest} -> case parse_unary(rest) do
          {nil, _} -> raise "Expected expression after #{op}"
          {b, rest} -> {%Expression{a: a, b: b, op: op}, rest}
        end
      end
    end
  end

  defp parse_factor_op(l = [t|rest]) do 
    case t do
      %Token{type: :mul} -> {t, rest}
      %Token{type: :div} -> {t, rest}
      _ -> {nil, l}
    end
  end

  defp parse_unary(l) do
    case parse_unary_op(l) do
      {nil, rest} -> parse_function_call(rest)
      {op, rest} -> case parse_unary(rest) do
          {nil, _} -> raise "Expected expression after #{op}"
          {a, rest} -> {%Expression{a: a, op: op}, rest}
      end
    end
  end

  defp parse_unary_op(l = [t|rest]) do 
    case t do
      %Token{type: :not} -> {t, rest}
      _ -> {nil, l}
    end
  end

  defp parse_function_call(l) do
    case parse_value(l) do
      {nil, rest} -> {nil, rest}
      {a, rest} -> case parse_arguments(rest) do
        {nil, rest} -> {a, rest}
        {args, rest} -> {%Expression{a: a, op: %Call{arguments: args}}, rest}
      end
    end
  end

  defp parse_value(l = [t|rest]) do
    case t do
      %Token{type: :identifier} -> {t, rest}
      %Token{type: :string} -> {t.value, rest}
      %Token{type: :number} -> {t.value, rest}
      %Token{type: :keyword, value: true} -> {t.value, rest}
      %Token{type: :keyword, value: false} -> {t.value, rest}
      %Token{type: :openPar} -> case parse_expression(rest) do
        {nil, _} -> raise "Expected an expression #{t}"
        {exp, rest} -> case rest do
          [%Token{type: :closePar}|rest] -> {exp, rest}
          _ -> raise "Unclosed #{t}"
        end
      end
      _ -> {nil, l}
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
  defp _parse_parameters([%Token{type: :closePar}|rest]) do
    {[], rest}
  end
  defp _parse_parameters(_) do 
    raise "expected <identifier><coma> or <identifier><closeParenthesis> in parameter list"
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

