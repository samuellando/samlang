defmodule Parser do
  def parse(l) do
    {n, _} = _parse(l)
    n
  end

  def _parse(l) do
    [t|rest] = l
    cond do
      t.type == :openCurly -> parseObject(l)
      t.type == :openSquare -> parseList(l)
      t.type == :number -> {t, rest}
      t.type == :string -> {t, rest}
      t.type == :keyword -> {t, rest}
      true -> raise "Unexpected token #{t}"
    end
  end

  def parseObject(l) do
    [%Token{type: :openCurly}|rest] = l
    {o, rest} = parseFields(rest)
    [%Token{type: :closeCurly}|rest] = rest
    {o, rest}
  end

  def parseFields(l) do
    _parseFields(l, %{})
  end

  def _parseFields([%Token{type: :string, value: k}, %Token{type: :colon}| rest], acc) do
    {v, rest} = _parse(rest)
    [t|rest] = rest
    acc = Map.put(acc, k, v)
    cond do
      t.type == :coma -> _parseFields(rest, acc) 
      t.type == :closeCurly -> {acc, [t|rest]}
      true -> raise "Unexpected token #{t}"
    end
  end


  def parseList(l) do
    [%Token{type: :openSquare}|rest] = l
    {l, rest} = parseItems(rest)
    [%Token{type: :closeSquare}|rest] = rest
    {l, rest}
  end

  def parseItems(l) do
    {v, rest} = _parse(l)
    [t|rest] = rest
    cond do
      t.type == :coma -> 
        {l, rest} = parseItems(rest)
        {[v|l], rest}
      t.type == :closeSquare -> {[v], [t|rest]}
      true -> raise "Unexpected token #{t}"
    end
  end
end

