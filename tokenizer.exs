defmodule Token do
  defstruct type: :openCurly, value: "", row: 0, col: 0
end

defimpl String.Chars, for: Token do
  def to_string(t) do 
    "#{t.type} #{t.value} at #{t.row}:#{t.col}"
  end
end

defmodule Tokenizer do
  def tokenize(s) do 
    _tokenize(String.to_charlist(s), 1, 1)
  end

  defp _tokenize([], _, _), do: []

  defp _tokenize(chars, row, col) do
    case scan_keyword_token(chars, row, col) do
      {nil, _, _, _} -> case scan_non_keyword_token(chars, row, col) do
        {nil, row, col, rest} -> _tokenize(rest, row, col)
        {t, row, col, rest} -> [t|_tokenize(rest, row, col)]
      end
      {kw, row, col, rest} -> [kw|_tokenize(rest, row, col)]
    end
  end

  defp scan_keyword_token(chars, row, col) do
    case chars do
      [?w,?h,?i,?l,?e|rest] -> {%Token{type: :keyword, value: "while", row: row, col: col}, row, col+5, rest} 
      [?i,?f|rest] -> {%Token{type: :keyword, value: "if", row: row, col: col}, row, col+2, rest} 
      [?e,?l,?s,?e|rest] -> {%Token{type: :keyword, value: "else", row: row, col: col}, row, col+4, rest} 
      [?f,?u,?n,?c|rest] -> {%Token{type: :keyword, value: "func", row: row, col: col}, row, col+4, rest} 
      [?r,?e,?t,?u,?r,?n|rest] -> {%Token{type: :keyword, value: "return", row: row, col: col}, row, col+6, rest} 
      [?t,?r,?u,?e|rest] -> {%Token{type: :keyword, value: "true", row: row, col: col}, row, col+4, rest} 
      [?f,?a,?l,?s,?e|rest] -> {%Token{type: :keyword, value: "false", row: row, col: col}, row, col+5, rest} 
      _ -> {nil, row, col, chars}
    end
  end

  # Whitespace
  defp scan_non_keyword_token([?\s|rest], row, col) do
      {nil, row, col+1, rest}
  end
  defp scan_non_keyword_token([?\t|rest], row, col) do
      {nil, row, col+1, rest}
  end
  defp scan_non_keyword_token([?\n|rest], row, col) do
      {%Token{type: :newLine, row: row, col: col}, row+1, 1, rest}
  end
  # Multi character sequences 
  defp scan_non_keyword_token([?"|rest], row, col) do
      scan_string([?"|rest], row, col)
  end
  defp scan_non_keyword_token([c|rest], row, col) when c in ?0..?9 do
      scan_number([c|rest], row, col)
  end
  defp scan_non_keyword_token([c|rest], row, col) when c in ?a..?z or c in ?A..?Z or c == ?_ do
      scan_identifier([c|rest], row, col)
  end
  # Single char tokens
  defp scan_non_keyword_token([?{|rest], row, col) do
      {%Token{type: :openCurly, row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?}|rest], row, col) do
      {%Token{type: :closeCurly, row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?[|rest], row, col) do
      {%Token{type: :openSquare, row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?]|rest], row, col) do
      {%Token{type: :closeSquare, row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?(|rest], row, col) do
      {%Token{type: :openPar, row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?)|rest], row, col) do
      {%Token{type: :closePar, row: row, col: col}, row, col+1, rest}
  end
  # operators
  defp scan_non_keyword_token([?=,?=|rest], row, col) do
      {%Token{type: :equal, value: "==", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?!,?=|rest], row, col) do
      {%Token{type: :notEqual, value: "!=", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?>,?=|rest], row, col) do
      {%Token{type: :ge, value: ">=", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?<,?=|rest], row, col) do
      {%Token{type: :le, value: "<=", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?>|rest], row, col) do
      {%Token{type: :greater, value: ">", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?<|rest], row, col) do
      {%Token{type: :less, value: "<", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?+|rest], row, col) do
      {%Token{type: :add, value: "+", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?-|rest], row, col) do
      {%Token{type: :sub, value: "-", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?/|rest], row, col) do
      {%Token{type: :div, value: "/", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?*|rest], row, col) do
      {%Token{type: :mul, value: "*", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?=|rest], row, col) do
      {%Token{type: :assign, value: "=", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([?,|rest], row, col) do
      {%Token{type: :coma, value: ",", row: row, col: col}, row, col+1, rest}
  end
  defp scan_non_keyword_token([c|_], row, col) do
    raise "Unexpected token #{c} at #{row}:#{col}"
  end

  defp scan_number(l,row, col) do
    {n, rest} = _scan_number(l)
    {%Token{type: :number, value: List.to_string(n), row: row, col: col}, row, col + length(n), rest}
  end
  defp _scan_number([c|rest]) when c in ?0..?9 do
    {n, rest} = _scan_number(rest)
    {[c|n], rest}
  end
  defp _scan_number(l) do
    {[], l}
  end

  defp scan_identifier(l, row, col) do
    {id, rest} = _scan_identifier(l)
    {%Token{type: :identifier, value: List.to_string(id), row: row, col: col}, row, col + length(id), rest}
  end
  defp _scan_identifier([c|rest]) when c in ?a..?z or c in ?A..?Z or c == ?_ do
    {id, rest} = _scan_identifier(rest)
    {[c|id], rest}
  end
  defp _scan_identifier(l) do
    {[], l}
  end

  defp scan_string([?"|rest],row, col) do
    {s, rest} = _scan_string(rest, row)
    {%Token{type: :string, value: List.to_string(s), row: row, col: col}, row, col + length(s), rest}
  end
  defp _scan_string([c,?"|rest], _) do
    {[c], rest}
  end
  defp _scan_string([_, ?\n|_], row) do
    raise "Unclosed string on line #{row}"
  end
  defp _scan_string([c|rest], row) do
    {s, rest} = _scan_string(rest, row)
    {[c|s], rest}
  end
end
