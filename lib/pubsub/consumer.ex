defmodule Pubsub.Consumer do
  use GenServer
  require Logger

  @contract_queues ["test_1", "test_2", "test_3", "test_4", "test_5"]

  # SUBSCRIPTIONS: When you create a topic, the only way to get messages from that topic
  # is through a subscription. That means that when we create a topic, we should create
  # a corresponding subscription for it.

  def start_link(name) do
    subscriptions =
      Enum.map(@contract_queues, fn queue ->
        %Kane.Subscription{
          name: queue,
          topic: %Kane.Topic{
            name: queue
          }
        }
      end)

    redis_conn = Process.whereis(:redix)

    GenServer.start_link(
      __MODULE__,
      %{queues: @contract_queues, subscriptions: subscriptions, redis_conn: redis_conn},
      name: name
    )
  end

  @impl true
  def init(state) do
    Process.send(self(), :process_messages, [])

    {:ok, state}
  end

  @impl true
  def handle_info(:process_messages, state) do
    Process.send_after(self(), :process_messages, 5_000)

    subscription = Enum.random(state.subscriptions)

    case try_acquire_lock(subscription.topic.name, state.redis_conn) do
      {:ok, 1} ->
        {:ok, [message]} = pull_from_top(subscription)
        work_on_message(subscription, message, state.redis_conn)

      {:ok, 0} ->
        :nothing
    end

    {:noreply, state}
  end

  defp try_acquire_lock(queue, redis_conn) do
    # Maybe we can put some timestamp as the value (now + some amount of minutes/hours/whatever)
    # and then as a protection against deadlocks unlock a queue if the timestamp is before now.
    Redix.command(redis_conn, ["SETNX", queue, "some_value"])
  end

  defp pull_from_top(subscription) do
    Kane.Subscription.pull(subscription, 1)
  end

  defp work_on_message(subscription, message, redis_conn) do
    Logger.info("#{inspect(self())} Working on message with id #{message.id} in queue #{subscription.name}")
    acknowledge(subscription, message)
    Redix.command(redis_conn, ["DEL", subscription.topic.name])
  end

  defp acknowledge(subscription, messages) do
    Kane.Subscription.ack(subscription, messages)
  end
end
