defmodule PatternVM.Composite do
  @behaviour PatternVM.PatternBehavior

  defmodule Component do
    defstruct [:id, :name, :type, :children, :data]

    def new(id, name, type, data \\ %{}) do
      %__MODULE__{
        id: id,
        name: name,
        type: type,
        children: [],
        data: data
      }
    end

    def add_child(%__MODULE__{} = component, %__MODULE__{} = child) do
      # Avoid adding duplicates by checking if child already exists
      if Enum.any?(component.children, fn c -> c.id == child.id end) do
        component
      else
        %{component | children: [child | component.children]}
      end
    end

    def remove_child(%__MODULE__{} = component, child_id) do
      %{
        component
        | children: Enum.reject(component.children, fn child -> child.id == child_id end)
      }
    end

    def find_child(%__MODULE__{} = component, child_id) do
      Enum.find(component.children, fn child -> child.id == child_id end)
    end
  end

  def pattern_name, do: :composite

  def initialize(config) do
    {:ok,
     %{
       composites: %{},
       name: Map.get(config, :name, :composite)
     }}
  end

  def handle_interaction(:create_component, %{id: id, name: name, type: type} = params, state) do
    data = Map.get(params, :data, %{})
    component = Component.new(id, name, type, data)
    updated_composites = Map.put(state.composites, id, component)
    new_state = %{state | composites: updated_composites}

    PatternVM.Logger.log_interaction("Composite", "create_component", %{
      id: id,
      name: name,
      type: type
    })

    {:ok, component, new_state}
  end

  def handle_interaction(:add_child, %{parent_id: parent_id, child_id: child_id}, state) do
    with {:ok, parent} <- Map.fetch(state.composites, parent_id),
         {:ok, child} <- Map.fetch(state.composites, child_id) do
      # Add child to parent
      updated_parent = Component.add_child(parent, child)
      updated_composites = Map.put(state.composites, parent_id, updated_parent)
      new_state = %{state | composites: updated_composites}

      PatternVM.Logger.log_interaction("Composite", "add_child", %{
        parent_id: parent_id,
        child_id: child_id
      })

      {:ok, updated_parent, new_state}
    else
      :error ->
        missing =
          cond do
            not Map.has_key?(state.composites, parent_id) ->
              "Parent component not found: #{parent_id}"

            not Map.has_key?(state.composites, child_id) ->
              "Child component not found: #{child_id}"

            true ->
              "Components not found"
          end

        PatternVM.Logger.log_interaction("Composite", "error", %{error: missing})

        {:error, missing, state}
    end
  end

  def handle_interaction(:get_component, %{id: id}, state) do
    case Map.fetch(state.composites, id) do
      {:ok, component} ->
        # Deep copy with full component objects in children
        component_with_children = deep_copy_component(component, state.composites)

        PatternVM.Logger.log_interaction("Composite", "get_component", %{id: id})
        {:ok, component_with_children, state}

      :error ->
        PatternVM.Logger.log_interaction("Composite", "error", %{
          error: "Component not found: #{id}"
        })

        {:error, "Component not found: #{id}", state}
    end
  end

  # Recursively build the full component tree
  defp deep_copy_component(component, all_components) do
    children = Enum.map(component.children, fn child ->
      child_id = child.id
      case Map.fetch(all_components, child_id) do
        {:ok, full_child} -> deep_copy_component(full_child, all_components)
        :error -> child  # Fallback if child isn't found (shouldn't happen)
      end
    end)

    %{component | children: children}
  end

  def handle_interaction(:remove_component, %{id: id}, state) do
    case Map.pop(state.composites, id) do
      {nil, _} ->
        PatternVM.Logger.log_interaction("Composite", "error", %{
          error: "Component not found: #{id}"
        })

        {:error, "Component not found: #{id}", state}

      {component, updated_composites} ->
        # Also need to remove this component from any parents
        cleaned_composites =
          Enum.reduce(updated_composites, updated_composites, fn {parent_id, parent}, acc ->
            updated_parent = Component.remove_child(parent, id)
            Map.put(acc, parent_id, updated_parent)
          end)

        new_state = %{state | composites: cleaned_composites}

        PatternVM.Logger.log_interaction("Composite", "remove_component", %{id: id})

        {:ok, component, new_state}
    end
  end
end
