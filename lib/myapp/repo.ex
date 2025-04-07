defmodule PatternVm.Repo do
  use Ecto.Repo,
    otp_app: :pattern_vm,
    adapter: Ecto.Adapters.Postgres
end
