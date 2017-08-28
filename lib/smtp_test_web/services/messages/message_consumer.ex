defmodule MyApp.Consumer do
  use GenServer
  use AMQP

  @exchange "email_processing"
  @queue "email_delivery"

  @status_exchange "email_status"
  @status_queue "email_status"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_opts) do
    rabbitmq_connect()
  end

  defp rabbitmq_connect do
    IO.puts "connecting..."
    :timer.sleep(5_000)
    case Connection.open("amqp://guest:guest@10.0.2.2:5672") do
      {:ok, conn} ->
        Process.link(conn.pid)
        {:ok, chan} = Channel.open(conn)
        Confirm.select(chan)
        Basic.qos(chan, prefetch_count: 1000)

        # status queue
        Queue.declare(chan, @status_queue, durable: true)
        Exchange.declare(chan, @status_exchange, :topic, durable: true)
        Queue.bind(chan, @status_queue, @status_exchange, routing_key: "#")

        # consumer queue
        Queue.declare(chan, @queue, durable: true,
                                    arguments: [{"x-dead-letter-exchange", :longstr, @status_exchange},
                                                {"x-dead-letter-routing-key", :longstr, @status_queue}])
        Exchange.declare(chan, @exchange, :topic, durable: true)
        Queue.bind(chan, @queue, @exchange, routing_key: "#")


        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}
      {:error, _} ->
        rabbitmq_connect()
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    IO.inspect(reason, label: "received :DOWN")
    {:ok, chan} = rabbitmq_connect()
    {:noreply, chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    IO.inspect(consumer_tag, label: "AMQPConsumer connected")
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    IO.inspect(consumer_tag, label: "AMQPConsumer unexpectedly disconnected")
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan) do
    IO.inspect(consumer_tag, label: "AMQPConsumer Basic.cancel")
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    spawn_link fn -> consume(chan, tag, redelivered, payload) end
    {:noreply, chan}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "RequestConsumer unexpected message")
    {:noreply, state}
  end

  defp consume(channel, tag, redelivered, payload) do
    response = Poison.decode!(payload)
    email = response["attributes"]

    MyApp.Email.send_email(email)
      |> MyApp.Mailer.deliver_now

    produce_status_success(channel, response)
    Basic.ack(channel, tag)
  rescue
    exception ->
      IO.puts "an error pusing request!"
      IO.inspect(exception, [label: "RequestConsumer exception"])
      Basic.reject(channel, tag, requeue: not redelivered)
  end

  defp produce_status_success(channel, response) do
    message = Map.merge(response, %{"status" => "success"})
    payload = Poison.encode!(message)
    Basic.publish(channel, @status_exchange, "", payload, persistent: true)
    Confirm.wait_for_confirms_or_die(channel)
  end
end
