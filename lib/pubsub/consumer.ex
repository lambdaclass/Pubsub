defmodule Pubsub.Consumer do
  use GenServer
  require Logger

  alias Pubsub.RustExpensiveCode

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
    Process.send_after(self(), :process_messages, :rand.uniform(10) * 1_000)

    look_for_work(state.subscriptions, state.redis_conn)

    {:noreply, state}
  end

  defp look_for_work([], _redis_conn) do
    :nothing
  end

  defp look_for_work(subscriptions, redis_conn) do
    subscription = Enum.random(subscriptions)

    case try_acquire_lock(subscription.topic.name, redis_conn) do
      {:ok, 1} ->
        case pull_from_top(subscription) do
          {:ok, [message]} ->
            work_on_message(subscription, message, redis_conn)

          {:ok, []} ->
            unlock_queue(subscription.topic.name, redis_conn)
            look_for_work(List.delete(subscriptions, subscription), redis_conn)
        end

      {:ok, 0} ->
        look_for_work(List.delete(subscriptions, subscription), redis_conn)
    end
  end

  defp try_acquire_lock(queue, redis_conn) do
    Redix.command(redis_conn, ["SETNX", queue, "some_value"])
    # TTL of 10 seconds
    Redix.command(redis_conn, ["EXPIRE", queue, 10])
  end

  defp pull_from_top(subscription) do
    Kane.Subscription.pull(subscription, 1)
  end

  defp work_on_message(subscription, message, redis_conn) do
    Logger.info(
      "#{inspect(self())} Working on message with id #{message.id} in queue #{subscription.name}"
    )

    case RustExpensiveCode.do_work() do
      :ok ->
        # We can use the ack deadline feature and only acknowledge on success as long
        # as the work we're doing takes less than the maximum ack deadline.
        acknowledge(subscription, message)
        unlock_queue(subscription.topic.name, redis_conn)

      {:error, error_message} ->
        # Here the message needs to be republished
        # If we use the deadline this just amounts to doing nothing
        # apart from unlocking the queue
        Logger.info("#{__MODULE__} Error running rust code")
        unlock_queue(subscription.topic.name, redis_conn)
        # notify_us_somehow_that_this_happened
    end
  end

  defp unlock_queue(queue, redis_conn) do
    Redix.command(redis_conn, ["DEL", queue])
  end

  defp acknowledge(subscription, messages) do
    Kane.Subscription.ack(subscription, messages)
  end
end
