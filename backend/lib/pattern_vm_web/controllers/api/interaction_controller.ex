defmodule PatternVMWeb.API.InteractionController do
  use PatternVMWeb, :controller

  def interact(conn, %{"pattern" => pattern, "action" => action, "params" => params}) do
    pattern_atom = String.to_atom(pattern)
    action_atom = String.to_atom(action)

    # Convert string keys to atoms (with safety constraints)
    processed_params = process_params(params)

    case PatternVM.interact(pattern_atom, action_atom, processed_params) do
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})

      result ->
        json(conn, %{result: result})
    end
  end

  # Safely convert params from string keys to atom keys
  defp process_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {k, v}, acc ->
      # Only convert known keys to atoms to prevent atom table overflow
      if String.starts_with?(k, "_") do
        # Keep strings with underscore prefix as strings
        Map.put(acc, k, process_params(v))
      else
        # Otherwise try to convert to existing atom
        try do
          atom_key = String.to_existing_atom(k)
          Map.put(acc, atom_key, process_params(v))
        rescue
          ArgumentError ->
            # If atom doesn't exist, keep as string
            Map.put(acc, k, process_params(v))
        end
      end
    end)
  end

  defp process_params(params) when is_list(params) do
    Enum.map(params, &process_params/1)
  end

  defp process_params(params), do: params
end
