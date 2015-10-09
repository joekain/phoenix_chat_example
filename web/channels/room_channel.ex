defmodule Chat.RoomChannel do
  use Phoenix.Channel
  require Logger

  defp start_tweet_streamer do
    configure_extwitter
    parent = self

    spawn_link fn ->
      process_extwitter(parent)
    end
  end

  defp process_extwitter(parent) do
    stream = ExTwitter.stream_sample()
    for message <- stream do
      case message do
        tweet = %ExTwitter.Model.Tweet{} ->
          send(parent, {:tweet, tweet.user.name, tweet.text})
        true -> true
      end
    end
  end

  defp configure_extwitter do
    ExTwitter.configure(
      consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
      consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
      access_token: System.get_env("TWITTER_ACCESS_TOKEN"),
      access_token_secret: System.get_env("TWITTER_ACCESS_SECRET")
    )
  end

  @doc """
  Authorize socket to subscribe and broadcast events on this channel & topic

  Possible Return Values

  `{:ok, socket}` to authorize subscription for channel for requested topic

  `:ignore` to deny subscription/broadcast on this channel
  for the requested topic
  """
  def join("rooms:lobby", message, socket) do
    Process.flag(:trap_exit, true)
    send(self, {:after_join, message})

    if ! socket.assigns[:tweet_streamer] do
      assign(socket, :tweet_streamer, start_tweet_streamer)
    end

    {:ok, socket}
  end

  def join("rooms:" <> _private_subtopic, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:after_join, msg}, socket) do
    broadcast! socket, "user:entered", %{user: msg["user"]}
    push socket, "join", %{status: "connected"}
    {:noreply, socket}
  end
  # def handle_info(:ping, socket) do
  #   push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
  #   {:noreply, socket}
  # end

  def handle_info({:tweet, name, text}, socket) do
    broadcast! socket, "new:msg", %{user: name, body: text}
    {:noreply, socket}
  end

  def terminate(reason, _socket) do
    Logger.debug"> leave #{inspect reason}"
    :ok
  end

  def handle_in("new:msg", msg, socket) do
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end
end
