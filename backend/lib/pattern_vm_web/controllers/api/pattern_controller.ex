defmodule PatternVMWeb.API.PatternController do
  use PatternVMWeb, :controller

  def index(conn, _params) do
    # Get all registered patterns
    # This would need an API method from PatternVM
    patterns = PatternVM.get_registered_patterns()
    json(conn, %{patterns: patterns})
  end

  def create(conn, %{"pattern" => pattern_params}) do
    # Register a new pattern
    with {:ok, name} <- Map.fetch(pattern_params, "name"),
         {:ok, type} <- Map.fetch(pattern_params, "type"),
         {:ok, config} <- Map.fetch(pattern_params, "config"),
         {:ok, pattern_id} <- register_pattern(name, type, config) do

      conn
      |> put_status(:created)
      |> json(%{id: pattern_id})
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required parameters"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def show(conn, %{"id" => id}) do
    # Get information about a specific pattern
    case PatternVM.get_pattern(id) do
      {:ok, pattern} ->
        json(conn, pattern)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pattern not found"})
    end
  end

  # Helper to register pattern based on string type
  defp register_pattern(name, type, config) do
    atom_name = String.to_atom(name)
    module = case type do
      "singleton" -> PatternVM.Singleton
      "factory" -> PatternVM.Factory
      "observer" -> PatternVM.Observer
      "builder" -> PatternVM.Builder
      "strategy" -> PatternVM.Strategy
      "adapter" -> PatternVM.Adapter
      "decorator" -> PatternVM.Decorator
      "composite" -> PatternVM.Composite
      "proxy" -> PatternVM.Proxy
      "chain_of_responsibility" -> PatternVM.ChainOfResponsibility
      "command" -> PatternVM.Command
      _ -> {:error, "Unknown pattern type: #{type}"}
    end

    case module do
      {:error, _} = error -> error
      _ ->
        PatternVM.register_pattern(module, Map.put(config, :name, atom_name))
        {:ok, name}
    end
  end
end
