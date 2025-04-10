defmodule PatternVM.PatternBehavior do
  @callback pattern_name() :: atom()
  @callback initialize(map()) :: {:ok, map()} | {:error, any()}
  @callback handle_interaction(atom(), any(), map()) ::
              {:ok, any(), map()} | {:error, any(), map()}
end
