defmodule MyApp.Consumer do
  use GenServer
  use AMQP

  @exchange "email_processing"
  @queue "email_delivery"
  @queue_error "#{@queue}_error"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(_opts) do
    rabbitmq_connect()
  end

  defp rabbitmq_connect do
    case Connection.open("amqp://guest:guest@localhost") do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        Basic.qos(chan, prefetch_count: 10)
        Queue.declare(chan, @queue_error, durable: true)
        Queue.declare(chan, @queue, durable: true)

        Exchange.declare(chan, @exchange, :topic, durable: true)
        Queue.bind(chan, @queue, @exchange, routng_key: '#')

        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}
      {:error, _} ->
        :timer.sleep(10_000)
        rabbitmq_connect()
    end
  end

  # Callbacks

  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
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
    spawn fn -> consume(chan, tag, redelivered, payload) end
    {:noreply, chan}
  end

  def handle_info(msg, state) do
    IO.inspect(msg, label: "RequestConsumer unexpected message")
    {:noreply, state}
  end

  defp consume(channel, tag, redelivered, payload) do
    IO.inspect payload, label: "got a message!"

    :timer.sleep(5000)

    IO.inspect payload, label: "processed a message!"

    Basic.ack channel, tag
  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise comsumer will stop
    # receiving messages.
    exception ->
      IO.puts "an error pusing request!"
      IO.inspect(exception, [label: "RequestConsumer exception"])
      Basic.reject channel, tag, requeue: not redelivered
      IO.puts "WebApi.WebsocketClient ERROR converting #{payload}"
  end
end
