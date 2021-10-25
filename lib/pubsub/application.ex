defmodule Pubsub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    consumer_children =
      Enum.map(0..9, fn i ->
        Supervisor.child_spec({Pubsub.Consumer, String.to_atom("Pubsub.Consumer_#{i}")},
          id: String.to_atom("Pubsub.Consumer_#{i}")
        )
      end)

    producer_children =
      Enum.map(0..9, fn i ->
        Supervisor.child_spec({Pubsub.Producer, String.to_atom("Pubsub.Producer_#{i}")},
          id: String.to_atom("Pubsub.Producer_#{i}")
        )
      end)

    children =
      [
        # Starts a worker by calling: Pubsub.Worker.start_link(arg)
        # {Pubsub.Worker, arg},
        %{
          id: :redix,
          start: {Redix, :start_link, ["redis://localhost:6379", [name: :redix]]}
        }
      ] ++ producer_children ++ consumer_children


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pubsub.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
