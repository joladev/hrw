defmodule HRW do
  @moduledoc """
  HRW (Highest Random Weight), also known as rendezvous hashing, maps a key
  to a node out of a set in a way that stays stable when nodes are added or
  removed.

  This module is stateless. For O(log n) lookups over large node sets, see
  `HRW.Skeleton`.
  """

  @doc """
  Returns the node responsible for `key`.

  Each node is hashed together with the key; the highest-scoring node wins.

  ## Options

    * `:hash_fn` - a function `term -> integer`. Defaults to `&:erlang.phash2/1`.

  ## Examples

      iex> HRW.owner("192.168.0.1", ["server1", "server2", "server3"])
      "server2"

  """
  @spec owner(term(), [term()], keyword()) :: term()
  def owner(key, nodes, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)

    nodes
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.max_by(fn node ->
      hash_fn.({key, node})
    end)
  end

  @doc """
  Returns the top `count` nodes responsible for `key`, in descending weight order.

  ## Options

    * `:hash_fn` - a function `term -> integer`. Defaults to `&:erlang.phash2/1`.

  ## Examples

      iex> HRW.owners("192.168.0.1", ["server1", "server2", "server3"], 2)
      ["server2", "server3"]

  """
  @spec owners(term(), [term()], non_neg_integer(), keyword()) :: [term()]
  def owners(key, nodes, count, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)

    nodes
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.sort_by(fn node -> hash_fn.({key, node}) end, :desc)
    |> Enum.take(count)
  end
end
