defmodule HRW.Skeleton do
  @moduledoc """
  A skeleton-based variant of HRW that gives O(log n) lookups by grouping
  nodes into clusters and routing keys through a virtual tree.

  Build the skeleton once with `build/2`, then pass it to each `owner/3` call.
  The skeleton is plain data, not a process.
  """

  defstruct [:clusters, :fanout, :levels]

  @type t :: %__MODULE__{
          clusters: tuple(),
          fanout: pos_integer(),
          levels: non_neg_integer()
        }

  @doc """
  Builds a skeleton from `nodes`.

  ## Options

    * `:fanout` - branching factor of the virtual tree. Defaults to `3`.
    * `:cluster_size` - target number of nodes per cluster. Defaults to `16`.

  ## Examples

      iex> HRW.Skeleton.build(["server1", "server2", "server3"])
      #HRW.Skeleton<3 nodes, fanout: 3>

  """
  @spec build([term()], keyword()) :: t()
  def build(nodes, opts \\ [])

  def build([], _opts) do
    raise ArgumentError, "HRW.Skeleton.build/2 requires a non-empty list of nodes"
  end

  def build(nodes, opts) do
    fanout = Keyword.get(opts, :fanout, 3)
    size = Keyword.get(opts, :cluster_size, 16)

    cluster_list = chunk_redistribute(nodes, size)
    clusters = List.to_tuple(cluster_list)
    count = tuple_size(clusters)
    levels = if count > 1, do: ceil(:math.log(count) / :math.log(fanout)), else: 0

    %__MODULE__{
      clusters: clusters,
      fanout: fanout,
      levels: levels
    }
  end

  @doc """
  Returns the node responsible for `key` in the given skeleton.

  ## Options

    * `:hash_fn` - a function `term -> integer`. Defaults to `&:erlang.phash2/1`.

  ## Examples

      iex> skeleton = HRW.Skeleton.build(["server1", "server2", "server3"])
      iex> HRW.Skeleton.owner("192.168.0.2", skeleton)
      "server3"

  """
  @spec owner(term(), t(), keyword()) :: term()
  def owner(key, %__MODULE__{} = skeleton, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)
    do_owner(key, skeleton, 0, hash_fn)
  end

  defp do_owner(key, %__MODULE__{clusters: {cluster}}, _salt, hash_fn) do
    Enum.max_by(cluster, fn node -> hash_fn.({key, node}) end)
  end

  defp do_owner(key, skeleton, salt, hash_fn) do
    index =
      Enum.reduce(0..(skeleton.levels - 1), 0, fn level, acc ->
        digit = Enum.max_by(0..(skeleton.fanout - 1), &hash_fn.({key, salt, level, &1}))
        acc * skeleton.fanout + digit
      end)

    if index < tuple_size(skeleton.clusters) do
      cluster = elem(skeleton.clusters, index)
      Enum.max_by(cluster, fn node -> hash_fn.({key, salt, index, node}) end)
    else
      do_owner(key, skeleton, salt + 1, hash_fn)
    end
  end

  defp chunk_redistribute(nodes, size) do
    # Deterministic ordering so the same node set always produces the same clusters.
    chunks =
      nodes
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.chunk_every(size)

    # An undersized last chunk would get the same routing probability as full chunks,
    # but with fewer nodes to share the load — roughly doubling their traffic.
    with [_ | _] = rest <- Enum.drop(chunks, -1),
         [_ | _] = last <- List.last(chunks),
         true <- length(last) < size do
      last
      |> Enum.with_index()
      |> Enum.reduce(rest, fn {node, index}, rest_clusters ->
        List.update_at(rest_clusters, rem(index, length(rest_clusters)), &[node | &1])
      end)
      |> Enum.map(&Enum.reverse/1)
    else
      _ -> chunks
    end
  end
end

defimpl Inspect, for: HRW.Skeleton do
  def inspect(%HRW.Skeleton{clusters: clusters, fanout: fanout}, _opts) do
    nodes =
      clusters
      |> Tuple.to_list()
      |> Enum.reduce(0, fn cluster, acc -> acc + length(cluster) end)

    label = if nodes == 1, do: "node", else: "nodes"
    "#HRW.Skeleton<#{nodes} #{label}, fanout: #{fanout}>"
  end
end
