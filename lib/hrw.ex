defmodule HRW do
  @moduledoc """
  HRW (Highest Random Weight), also known as rendezvous hashing, maps a key
  to a node out of a set in a way that stays stable when nodes are added or
  removed.

  This module is stateless. For O(log n) lookups over large node sets, build
  a skeleton with `build/2` and pass it to `owner/3`.
  """
  @behaviour HRW.Scorer

  defstruct [:hash_fn]

  @type t :: %__MODULE__{hash_fn: (term() -> integer()) | nil}

  @doc """
  Default scorer. Hashes `{key, node}` with the struct's `hash_fn`, falling
  back to `:erlang.phash2/1` when `hash_fn` is `nil`.

  Implements `HRW.Scorer`. Called internally whenever the default scorer is
  selected (no `:scorer` option, or `scorer: %HRW{}` passed explicitly).
  """
  @impl HRW.Scorer
  @spec score(t(), term(), term()) :: integer()
  def score(%__MODULE__{hash_fn: nil}, key, node), do: :erlang.phash2({key, node})
  def score(%__MODULE__{hash_fn: hash_fn}, key, node), do: hash_fn.({key, node})

  @doc """
  Returns the node responsible for `key`.

  Each node is hashed together with the key; the highest-scoring node wins.

  ## Options

    * `:scorer` - scoring strategy struct. Defaults to `%HRW{}`. Ignored when
      the second argument is a skeleton — pass `:scorer` to `build/2` instead.

  ## Examples

      iex> HRW.owner("192.168.0.1", ["server1", "server2", "server3"])
      "server2"

      iex> skeleton = HRW.build(["server1", "server2", "server3"])
      iex> HRW.owner("192.168.0.2", skeleton)
      "server3"
  """
  @spec owner(term(), [term()] | HRW.Skeleton.t(), keyword()) :: term()
  def owner(key, nodes_or_skeleton, opts \\ [])

  def owner(key, %HRW.Skeleton{} = skeleton, _opts) do
    HRW.Skeleton.owner(key, skeleton)
  end

  def owner(key, nodes, opts) do
    nodes =
      nodes
      |> Enum.sort()
      |> Enum.uniq()

    if scorer = Keyword.get(opts, :scorer) do
      %mod{} = scorer

      Enum.max_by(nodes, fn node ->
        mod.score(scorer, key, node)
      end)
    else
      Enum.max_by(nodes, fn node ->
        :erlang.phash2({key, node})
      end)
    end
  end

  @doc """
  Returns the top `count` nodes responsible for `key`, in descending weight order.

  ## Options

    * `:scorer` - scoring strategy struct. Defaults to `%HRW{}`.

  ## Examples

      iex> HRW.owners("192.168.0.1", ["server1", "server2", "server3"], 2)
      ["server2", "server3"]

  """
  @spec owners(term(), [term()], non_neg_integer(), keyword()) :: [term()]
  def owners(key, nodes, count, opts \\ []) do
    nodes =
      nodes
      |> Enum.sort()
      |> Enum.uniq()

    if scorer = Keyword.get(opts, :scorer) do
      %mod{} = scorer

      nodes
      |> Enum.sort_by(fn node -> mod.score(scorer, key, node) end, :desc)
      |> Enum.take(count)
    else
      nodes
      |> Enum.sort_by(fn node -> :erlang.phash2({key, node}) end, :desc)
      |> Enum.take(count)
    end
  end

  @doc """
  Builds a skeleton from `nodes` for O(log n) lookups.

  Pass the result to `owner/3`.

  ## Options

    * `:fanout` - branching factor of the virtual tree. Defaults to `3`.
    * `:cluster_size` - target number of nodes per cluster. Defaults to `16`.
    * `:scorer` - scoring strategy struct. Defaults to `%HRW{}`.

  ## Examples

      iex> HRW.build(["server1", "server2", "server3"], fanout: 3)
      #HRW.Skeleton<3 nodes, fanout: 3, scorer: %HRW{hash_fn: nil}>
  """
  @spec build([term()], keyword()) :: HRW.Skeleton.t()
  def build(nodes, opts \\ []) do
    HRW.Skeleton.build(nodes, opts)
  end
end
