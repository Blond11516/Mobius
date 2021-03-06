defmodule Mobius.Fixtures do
  @moduledoc false

  import ExUnit.Assertions

  alias Mobius.Core.Intents
  alias Mobius.Core.Opcode
  alias Mobius.Core.ShardInfo
  alias Mobius.Rest.Client
  alias Mobius.Services.Socket
  alias Mobius.Stubs

  @shard ShardInfo.new(number: 0, count: 1)

  def reset_services(_context) do
    Mobius.Application.reset_services()
  end

  def get_shard(_context) do
    [shard: @shard]
  end

  def stub_socket(_context) do
    Stubs.Socket.set_owner(@shard)
  end

  def stub_ratelimiter(_context) do
    Stubs.CommandsRatelimiter.set_owner()
  end

  def stub_connection_ratelimiter(_context) do
    Stubs.ConnectionRatelimiter.set_owner()
  end

  def handshake_shard(context) do
    send_hello()
    assert_receive_heartbeat()
    token = assert_receive_identify(context[:intents] || Intents.all_intents())

    session_id = random_hex(16)

    data = %{
      d: %{"session_id" => session_id},
      t: "READY",
      s: 1,
      op: Opcode.name_to_opcode(:dispatch)
    }

    Socket.notify_payload(data, @shard)

    [session_id: session_id, token: token]
  end

  def create_token(_context) do
    [token: random_hex(8)]
  end

  def create_rest_client(context) do
    [client: Client.new(token: context.token, max_retries: 0)]
  end

  # Utility functions
  @spec mock_gateway_bot(integer, integer) :: any
  def mock_gateway_bot(remaining \\ 1000, reset_after \\ 0) do
    app_info = %{
      "shards" => 1,
      "url" => "wss://gateway.discord.gg",
      "session_start_limit" => %{"remaining" => remaining, "reset_after" => reset_after}
    }

    url = Client.base_url() <> "/gateway/bot"
    Tesla.Mock.mock_global(fn %{url: ^url, method: :get} -> Mobius.Fixtures.json(app_info) end)
  end

  def send_hello(interval \\ 45_000) do
    send_payload(op: :hello, data: %{"heartbeat_interval" => interval})
  end

  def send_payload(opts) do
    data = %{
      op: Opcode.name_to_opcode(Keyword.fetch!(opts, :op)),
      d: Keyword.get(opts, :data),
      t: Keyword.get(opts, :type),
      s: Keyword.get(opts, :seq)
    }

    Socket.notify_payload(data, @shard)
  end

  def assert_receive_heartbeat(seq \\ 0) do
    msg = Opcode.heartbeat(seq)
    assert_receive {:socket_msg, ^msg}, 50
  end

  def assert_receive_identify(intents \\ Intents.all_intents()) do
    token = System.fetch_env!("MOBIUS_BOT_TOKEN")
    msg = Opcode.identify(@shard, token, intents)
    assert_receive {:socket_msg, ^msg}, 50
    token
  end

  @doc "Simulate the server closing the socket with an arbitrary code"
  def close_socket_from_server(close_num, reason) do
    # Closed is notified only when the server closes the connection
    Socket.notify_closed(@shard, close_num, reason)
    # Down is notified regardless of whether it was closed by the server or the client
    Socket.notify_down(@shard, reason)
    # Up is notified once it has reconnected by itself
    Socket.notify_up(@shard)
  end

  @chars String.codepoints("0123456789abcdef")
  def random_hex(len) do
    1..len
    |> Enum.map(fn _ -> Enum.random(@chars) end)
    |> Enum.join()
  end

  def json(term, status_code \\ 200) do
    {status_code, [{"content-type", "application/json"}], Jason.encode!(term)}
  end
end
