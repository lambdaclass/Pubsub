defmodule Pubsub.Producer do
  use GenServer

  @contract_queues [
    "test_1",
    "test_2",
    "test_3",
    "test_4",
    "test_5",
    "test_6",
    "test_7",
    "test_8",
    "test_9",
    "test_10"
  ]

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{queues: @contract_queues})
  end

  @impl true
  def init(state) do
    Process.send(self(), :send_messages, [])

    # This only has to happen once
    # FIXME: This code makes the app hang on startup
    # for contract_queue <- @contract_queues do
    #   Kane.Topic.create(contract_queue)
    #   Kane.Subscription.create(%Kane.Subscription{name: contract_queue, topic: %Kane.Topic{name: contract_queue}})
    # end

    {:ok, state}
  end

  @impl true
  def handle_info(:send_messages, state) do
    Process.send_after(self(), :send_messages, 60_000)

    Enum.each(state.queues, fn queue -> queue_message(queue) end)

    {:noreply, state}
  end

  def queue_message(queue) do
    topic = %Kane.Topic{name: queue}

    message = %Kane.Message{
      attributes: %{
        "do" => "some_work"
      }
    }

    Kane.Message.publish(message, topic)
  end
end
