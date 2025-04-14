defmodule PatternVM.DSL.AdapterTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  # Define adapter functions outside the DSL
  defmodule TestAdapters do
    def string_to_integer(str) do
      String.to_integer(str)
    end

    def list_to_map(list) do
      list
      |> Enum.with_index()
      |> Enum.into(%{}, fn {value, key} -> {key, value} end)
    end
  end

  test "adapter pattern definition and usage" do
    defmodule AdapterExample do
      use PatternVM.DSL
      import PatternVM.DSL.AdapterTest.TestAdapters, only: []

      # Define adapter pattern with adapters using MFA tuples
      adapter(:format_adapter, %{
        string_to_integer: {PatternVM.DSL.AdapterTest.TestAdapters, :string_to_integer, 1},
        list_to_map: {PatternVM.DSL.AdapterTest.TestAdapters, :list_to_map, 1}
      })

      # Define workflow to adapt string to integer
      workflow(
        :convert_string,
        sequence([
          adapt(:format_adapter, "42", :string_to_integer)
        ])
      )

      # Define workflow to adapt list to map
      workflow(
        :convert_list,
        sequence([
          adapt(:format_adapter, ["a", "b", "c"], :list_to_map)
        ])
      )
    end

    # Execute definition
    AdapterExample.execute()

    # Test string to integer adapter
    result1 = PatternVM.DSL.Runtime.execute_workflow(AdapterExample, :convert_string)
    assert result1.last_result == 42

    # Test list to map adapter
    result2 = PatternVM.DSL.Runtime.execute_workflow(AdapterExample, :convert_list)
    assert result2.last_result == %{0 => "a", 1 => "b", 2 => "c"}
  end

  test "registering adapters at runtime" do
    defmodule RuntimeAdapterExample do
      use PatternVM.DSL

      # Define empty adapter pattern
      adapter(:runtime_adapter)

      # Workflow to register an adapter
      workflow(
        :register_adapter,
        sequence([
          {:interact, :runtime_adapter, :register_adapter,
           %{
             for_type: :uppercase,
             adapter_fn: {__MODULE__, :uppercase, 1}
           }}
        ])
      )

      # Workflow to use the registered adapter
      workflow(
        :use_registered_adapter,
        sequence([
          adapt(:runtime_adapter, "hello world", :uppercase)
        ])
      )
    end

    # Execute definition
    RuntimeAdapterExample.execute()

    # Register the adapter
    PatternVM.DSL.Runtime.execute_workflow(RuntimeAdapterExample, :register_adapter)

    # Use the registered adapter
    result =
      PatternVM.DSL.Runtime.execute_workflow(RuntimeAdapterExample, :use_registered_adapter)

    assert result.last_result == "HELLO WORLD"
  end

  test "adapting complex objects" do
    defmodule ComplexAdapterExample do
      use PatternVM.DSL

      # Define factory to create products
      factory(:product_factory)

      # Define product adapter functions
      def to_json(product) do
        "{\"id\":\"#{product.id}\",\"type\":\"#{product.type}\"}"
      end

      def to_tuple(product) do
        {product.type, product.id}
      end

      # Define adapter for product transformation with MFA tuples
      adapter(:product_adapter, %{
        to_json: {__MODULE__, :to_json, 1},
        to_tuple: {__MODULE__, :to_tuple, 1}
      })

      # Workflow to create and adapt a product
      workflow(
        :product_to_json,
        sequence([
          create_product(:product_factory, :widget),
          adapt(:product_adapter, {:context, :last_result}, :to_json)
        ])
      )

      # Workflow to create and convert to tuple
      workflow(
        :product_to_tuple,
        sequence([
          create_product(:product_factory, :gadget),
          adapt(:product_adapter, {:context, :last_result}, :to_tuple)
        ])
      )
    end

    # Execute definition
    ComplexAdapterExample.execute()

    # Test product to JSON adapter
    result1 = PatternVM.DSL.Runtime.execute_workflow(ComplexAdapterExample, :product_to_json)
    assert is_binary(result1.last_result)
    assert String.contains?(result1.last_result, "\"type\":\"widget\"")

    # Test product to tuple adapter
    result2 = PatternVM.DSL.Runtime.execute_workflow(ComplexAdapterExample, :product_to_tuple)
    assert is_tuple(result2.last_result)
    assert elem(result2.last_result, 0) == :gadget
  end
end
