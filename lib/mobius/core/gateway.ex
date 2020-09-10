defmodule Mobius.Core.Gateway do
  @moduledoc false

  defstruct [:token, :session_id, :seq]

  @type t :: %__MODULE__{
          token: String.t(),
          session_id: String.t() | nil,
          seq: integer
        }

  @spec new(String.t()) :: t()
  def new(token) do
    %__MODULE__{
      token: token,
      session_id: nil,
      seq: 0
    }
  end

  @doc """
  Checks whether the gateway is in a session or not

      iex> has_session?(new("token"))
      false
      iex> has_session?(new("token") |> set_session_id("session"))
      true
      iex> has_session?(new("token") |> set_session_id("session") |> reset_session_id())
      false
  """
  @spec has_session?(t()) :: boolean
  def has_session?(gateway), do: gateway.session_id != nil

  @spec set_session_id(t(), String.t()) :: t()
  def set_session_id(gateway, session_id), do: %__MODULE__{gateway | session_id: session_id}

  @spec reset_session_id(t()) :: t()
  def reset_session_id(gateway), do: %__MODULE__{gateway | session_id: nil}

  @doc """
  Updates the sequence number to a new value

      iex> update_seq(new("token"), 42).seq
      42
  """
  @spec update_seq(t(), integer) :: t()
  def update_seq(gateway, seq), do: %__MODULE__{gateway | seq: seq}
end
