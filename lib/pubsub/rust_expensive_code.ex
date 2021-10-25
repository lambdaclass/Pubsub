defmodule Pubsub.RustExpensiveCode do
  use Rustler, otp_app: :pubsub, crate: "pubsub_rustexpensivecode"

  def do_work(), do: :erlang.nif_error(:nif_not_loaded)
end
