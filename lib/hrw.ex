defmodule HRW do
  @moduledoc """
  HRW is a consistent hashing algorithm that uses a hash function to distribute data across a set of nodes.
  """

  @doc """

  """

  def owner(key, nodes, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)

    {node, _} =
      nodes
      |> Enum.max_by(fn node ->
        hash_fn.({key, node})
      end)

    node
  end

  @doc """
  """
  def owners(key, nodes, count, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)

    nodes
    |> Enum.sort_by(fn node -> hash_fn.({key, node}) end, :desc)
    |> Enum.take(count)
  end
end
