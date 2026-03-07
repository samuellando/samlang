defmodule State do
  use Agent

  defstruct statements: [], environment: %{}, callStack: [], return: nil

  def create_initial(statements) do
    funcs = %{
      "print" => fn args, _ -> Enum.each(args, fn arg -> IO.puts("#{arg}") end) end,
      "+" => fn a, b -> a + b end,
      "-" => fn a, b -> a - b end,
      "/" => fn a, b -> a / b end,
      "*" => fn a, b -> a * b end,
      "==" => fn a, b -> a == b end,
      "!=" => fn a, b -> a != b end,
      ">=" => fn a, b -> a >= b end,
      "<=" => fn a, b -> a <= b end,
      ">" => fn a, b -> a > b end,
      "<" => fn a, b -> a < b end,
      "!" => fn a -> !a  end,
      "%" => fn a, b -> rem(a, b) end,
    }
    %State{statements: statements, environment: funcs}
  end

  def create_initial(statements, state) do
    i = create_initial(statements)
    %{i | 
      callStack: state.callStack,
      environment: Map.merge(i.environment, state.environment), 
    }
  end

  def return(%State{callStack: []}, _) do
    raise "Cannot call return from outside a function"
  end
  def return(state, v) do
    %{state | return: v}
  end

  def get_return(state) do
    state.return
  end

  def push_callstack(state, f) do
    %{state| callStack: [f|state.callStack]}
  end

  def step(state) do
    case state.statements do
      [] -> state
      l -> %{state | statements: tl(l)}
    end
  end

  def get_environment(state, name) do
    case state.environment[name] do
      nil -> nil
      v when is_pid(v) -> Agent.get(v, fn v -> v end)
      v -> v
    end
  end

  def set_environment(state, name, value) do
    case state.environment[name] do
      v when is_pid(v) -> 
        Agent.update(v, fn _ -> value end)
        state
      _ -> %{state | environment: Map.put(state.environment, name, value)}
    end
  end

  def allocate(state, name, value) do
    {:ok, agent} = Agent.start_link(fn -> value end)
    %{state | environment: Map.put(state.environment, name, agent)}
  end

  def pop_scope(state, nestedScope) do
    updated_environment = 
    Enum.reduce(nestedScope.environment, state.environment, fn {k, v}, acc ->
      if Map.has_key?(acc, k) do
        Map.put(acc, k, v)
      else
        acc
      end
    end)

    %{state | environment: updated_environment, return: nestedScope.return}
  end
end

defmodule Interpreter do
  def run(program) do
    execute_state(State.create_initial(program.statements))
  end

  defp execute_state(state = %State{statements: []}) do
    state
  end
  defp execute_state(state = %State{statements: [statement|_]}) do
    state = execute_statement(statement, state)
    case State.get_return(state) do
      nil -> execute_state(State.step(state))
      _ -> state 
    end
  end

  defp execute_statement(statement, state) do
    case statement do
      nil -> state
      %Assignment{} -> execute_assignment(statement, state)
      %Allocation{} -> execute_allocation(statement, state)
      %If{} -> execute_if(statement, state)
      %While{} -> execute_while(statement, state)
      %Func{} -> execute_func(statement, state)
      %Expression{} -> 
        execute_expression(statement, state)
        state
      %Return{} -> execute_return(statement, state)
      _ -> raise "Cirtical, expected a statement #{statement}"
    end
  end

  defp execute_assignment(s, state) do
    State.set_environment(state, s.identifier.value, execute_expression(s.expression, state))
  end

  defp execute_allocation(s, state) do
    State.allocate(state, s.identifier.value, execute_expression(s.expression, state))
  end

  defp execute_if(s, state) do
    cond = execute_expression(s.condition, state)
    if cond do
      block = State.create_initial(s.statements, state)
      block = execute_state(block)
      State.pop_scope(state, block)
    else
      block = State.create_initial(s.elseStatements, state)
      block = execute_state(block)
      State.pop_scope(state, block)
    end
  end

  defp execute_while(s, state) do
    cond = execute_expression(s.condition, state)
    if cond do
      block = State.create_initial(s.statements, state)
      block = execute_state(block)
      block = execute_while(s, block)
      State.pop_scope(state, block)
    else
      state
    end
  end

  defp execute_func(s, state) do
    call_f =  fn args, state ->
      if length(args) != length(s.parameters) do
        raise "Incorrect number of args for #{s.identifier}"
      end
      state = Enum.reduce(Enum.zip(args, s.parameters), State.create_initial(s.statements, state), fn {a, p}, state -> 
        State.set_environment(state, p.value, a)
      end)
      state = State.push_callstack(state, s.identifier)
      state = execute_state(state)
      State.get_return(state)
    end
    State.set_environment(state, s.identifier.value, call_f)
  end

  defp execute_call(id, args, state) do
    case State.get_environment(state, id.value) do
      nil -> raise "Function #{id} is not defined"
      f -> 
        if !is_function(f) do 
          raise "#{id} is not callable, got #{f}"
        end
        args = Enum.map(args, fn exp -> execute_expression(exp, state) end)
        f.(args, state)
    end
  end

  defp execute_return(s, state) do
    v = execute_expression(s.expression, state)
    State.return(state, v)
  end

  defp execute_expression(s, state) do
    case s do
      %Expression{a: a, b: nil, op: nil} -> execute_expression(a, state)
      %Expression{a: a, b: nil, op: %Call{arguments: args}} -> 
        execute_call(a, args, state)
      %Expression{a: a, b: nil, op: op} -> 
        a = execute_expression(a, state)
        State.get_environment(state, op.value).(a)
      %Expression{a: a, b: b, op: op} -> 
        a = execute_expression(a, state)
        b = execute_expression(b, state)
        State.get_environment(state, op.value).(a, b)
      t = %Token{type: :identifier, value: name} -> case State.get_environment(state, name) do
        nil -> raise "Variable #{t} is not defined"
        v -> v
      end
      v -> v
    end
  end
end
