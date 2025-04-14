defmodule PatternVM.DSL.MacroBugsTest do
  use ExUnit.Case

  test "reproducing macro traversal issue" do
    # This test doesn't use DSL, just demonstrates Macro traversal issue
    map_with_context = %{id: {:context, :some_key}, value: "test"}

    # Serialize and deserialize to simulate macro handling
    serialized = inspect(map_with_context)
    assert is_binary(serialized)

    # Successfully parsing it with Macro.escape
    escaped = Macro.escape(map_with_context)
    assert is_tuple(escaped) # It's now an AST representation

    # Basic validation to show it's a valid value
    {map, _bindings} = Code.eval_quoted(escaped)
    assert map.value == "test"
  end

  test "demonstrating how DSL should handle maps" do
    # Demonstrate safe pattern for map with context references

    # Create a DSL-like keyword representation that's safe for macros
    safe_map = [id: {:context, :some_key}, value: "test"]

    # This can be safely passed through macros
    quoted = quote do: Map.new(unquote(safe_map))

    # It evaluates correctly
    {result, _} = Code.eval_quoted(quoted, [some_key: "123"])
    assert is_map(result)
    assert result.value == "test"
  end
end
