# Configure for tests
Application.put_env(:pattern_vm, :pubsub_module, PatternVM.TestPubSub)

# Start the test PubSub
{:ok, _} = PatternVM.TestPubSub.start_link([])

ExUnit.start()

# Set testing mode
Application.put_env(:pattern_vm, :testing, true)
Application.put_env(:pattern_vm, :log_to_console, false)

# Start necessary services
{:ok, _} = Application.ensure_all_started(:phoenix_pubsub)

# Create test storage
:ets.new(:pattern_vm_children, [:set, :public, :named_table])

# Start core processes - only if not already started
unless Process.whereis(PatternVM.Supervisor) do
  {:ok, _} = PatternVM.Supervisor.start_link([])
end

unless Process.whereis(PatternVM) do
  {:ok, _} = PatternVM.start_link([])
end
