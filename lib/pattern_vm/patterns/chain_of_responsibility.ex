defmodule PatternVM.ChainOfResponsibility do
  @behaviour PatternVM.PatternBehavior

  def pattern_name, do: :chain_of_responsibility

  def initialize(config) do
    {:ok,
     %{
       handlers: Map.get(config, :handlers, []),
       name: Map.get(config, :name, :chain_of_responsibility)
     }}
  end

  def handle_interaction(
        :register_handler,
        %{name: name} = params,
        state
      ) do
    # Extract parameters with support for both naming conventions
    can_handle_fn = params[:can_handle] || params[:can_handle_fn]
    handle_fn = params[:handle_fn] || params[:handle]
    priority = params[:priority] || 0

    handler = %{
      name: name,
      can_handle: can_handle_fn,
      handle: handle_fn,
      priority: priority
    }

    # Rest of the function remains the same
    updated_handlers =
      [handler | state.handlers]
      |> Enum.sort_by(& &1.priority, :desc)

    new_state = %{state | handlers: updated_handlers}

    PatternVM.Logger.log_interaction("ChainOfResponsibility", "register_handler", %{
      name: name,
      priority: priority
    })

    {:ok, handler, new_state}
  end

  def handle_interaction(:process_request, %{request: request}, state) do
    # Find a handler that can handle this request
    handler =
      Enum.find(state.handlers, fn handler ->
        handler.can_handle.(request)
      end)

    case handler do
      nil ->
        PatternVM.Logger.log_interaction("ChainOfResponsibility", "unhandled_request", %{
          request: request
        })

        {:error, "No handler found for request", state}

      handler ->
        result = handler.handle.(request)

        PatternVM.Logger.log_interaction("ChainOfResponsibility", "request_handled", %{
          request: request,
          handler: handler.name,
          result: result
        })

        {:ok, result, state}
    end
  end

  def handle_interaction(:get_handler_chain, _params, state) do
    handler_names = Enum.map(state.handlers, & &1.name)

    PatternVM.Logger.log_interaction("ChainOfResponsibility", "get_handler_chain", %{
      handlers: handler_names
    })

    {:ok, handler_names, state}
  end
end
