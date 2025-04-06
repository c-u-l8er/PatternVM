defmodule PatternVM.Factory do
  @behaviour PatternVM.PatternBehavior

  defmodule Product do
    defstruct [:type, :id, :created_at]
  end

  # Pattern Behavior Implementation
  def pattern_name, do: :factory

  def initialize(_config), do: {:ok, %{products_created: 0}}

  def handle_interaction(:create_product, %{type: type}, state) do
    product = create_product(type)
    new_state = Map.update(state, :products_created, 1, &(&1 + 1))
    PatternVM.Logger.log_interaction("Factory", "create_product", %{type: type, product: product})
    {:ok, product, new_state}
  end

  # Product Creation Logic
  def create_product(:widget) do
    %Product{type: :widget, id: UUID.uuid4(), created_at: DateTime.utc_now()}
  end

  def create_product(:gadget) do
    %Product{type: :gadget, id: UUID.uuid4(), created_at: DateTime.utc_now()}
  end

  def create_product(:tool) do
    %Product{type: :tool, id: UUID.uuid4(), created_at: DateTime.utc_now()}
  end
end
