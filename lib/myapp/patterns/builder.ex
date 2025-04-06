defmodule PatternVM.Builder do
  @behaviour PatternVM.PatternBehavior

  defmodule ComplexProduct do
    defstruct [:name, :parts, :metadata]

    def new(name) do
      %__MODULE__{
        name: name,
        parts: [],
        metadata: %{}
      }
    end

    def add_part(%__MODULE__{} = product, part) do
      %{product | parts: [part | product.parts]}
    end

    def set_metadata(%__MODULE__{} = product, key, value) do
      %{product | metadata: Map.put(product.metadata, key, value)}
    end
  end

  # Pattern Behavior Implementation
  def pattern_name, do: :builder

  def initialize(_config), do: {:ok, %{}}

  def handle_interaction(:build_step_by_step, params, state) do
    product = build_complex_product(params)

    PatternVM.Logger.log_interaction("Builder", "build_product", %{
      params: params,
      product: product
    })

    {:ok, product, state}
  end

  # Builder methods
  def build_complex_product(%{name: name, parts: parts, metadata: metadata}) do
    product = ComplexProduct.new(name)

    # Add all parts
    product_with_parts =
      Enum.reduce(parts, product, fn part, acc ->
        ComplexProduct.add_part(acc, part)
      end)

    # Add all metadata
    Enum.reduce(metadata, product_with_parts, fn {key, value}, acc ->
      ComplexProduct.set_metadata(acc, key, value)
    end)
  end
end
