defmodule PatternVM.Repo do
  use Ecto.Repo,
    otp_app: :pattern_vm,
    adapter: Ecto.Adapters.Postgres

  def init(_, config) do
    # Dynamically configure the repository based on environment
    if config_env = Application.get_env(:pattern_vm, :database_url) do
      config = Keyword.put(config, :url, config_env)
    end

    {:ok, config}
  end
end
