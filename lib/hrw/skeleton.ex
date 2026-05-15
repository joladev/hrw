defmodule HRW.Skeleton do
  @moduledoc """
  Internal data structure backing `HRW.build/2` and `HRW.owner/3` for
  O(log n) lookups. Nodes are grouped into clusters and routed through a
  virtual tree. Plain data, not a process.

  Not intended for direct use — go through `HRW`.
  """

  defstruct [:clusters, :fanout, :levels, :scorer]

  @type t :: %__MODULE__{
          clusters: tuple(),
          fanout: pos_integer(),
          levels: non_neg_integer(),
          scorer: struct() | nil
        }

  @doc false
  @spec build([term()], keyword()) :: t()
  def build(nodes, opts \\ [])

  def build([], _opts) do
    raise ArgumentError, "HRW.Skeleton.build/2 requires a non-empty list of nodes"
  end

  def build(nodes, opts) do
    size = Keyword.get(opts, :cluster_size, 16)
    scorer = Keyword.get(opts, :scorer, %HRW{})

    cluster_list = chunk_redistribute(nodes, size)
    clusters = List.to_tuple(cluster_list)
    count = tuple_size(clusters)

    fanout = Keyword.get_lazy(opts, :fanout, fn -> optimal_fanout(count) end)
    levels = if count > 1, do: ceil(:math.log(count) / :math.log(fanout)), else: 0

    scorer =
      case scorer do
        %HRW.Weighted{} = weighted ->
          %{
            weighted
            | branch_weights: compute_branch_weights(cluster_list, fanout, levels),
              fanout: fanout
          }

        other ->
          other
      end

    %__MODULE__{
      clusters: clusters,
      fanout: fanout,
      levels: levels,
      scorer: scorer
    }
  end

  @doc false
  def owner(key, %__MODULE__{} = skeleton) do
    do_owner(key, skeleton, 0)
  end

  # We take the fast path when scorer and hash_fn are not overridden.
  defp do_owner(key, %__MODULE__{clusters: {cluster}, scorer: %HRW{hash_fn: nil}}, _salt) do
    Enum.max_by(cluster, fn node -> :erlang.phash2({key, node}) end)
  end

  defp do_owner(key, %__MODULE__{scorer: %HRW{hash_fn: nil}} = skeleton, salt) do
    index =
      Enum.reduce(0..(skeleton.levels - 1), 0, fn level, acc ->
        digit =
          Enum.max_by(0..(skeleton.fanout - 1), &:erlang.phash2({{key, salt, level, acc}, &1}))

        acc * skeleton.fanout + digit
      end)

    if index < tuple_size(skeleton.clusters) do
      cluster = elem(skeleton.clusters, index)
      Enum.max_by(cluster, fn node -> :erlang.phash2({{key, salt, index}, node}) end)
    else
      do_owner(key, skeleton, salt + 1)
    end
  end

  defp do_owner(key, %__MODULE__{clusters: {cluster}, scorer: %mod{} = scorer}, _salt) do
    Enum.max_by(cluster, fn node -> mod.score(scorer, key, node) end)
  end

  defp do_owner(key, %__MODULE__{scorer: %mod{} = scorer} = skeleton, salt) do
    index =
      Enum.reduce(0..(skeleton.levels - 1), 0, fn level, acc ->
        digit =
          Enum.max_by(0..(skeleton.fanout - 1), &mod.score(scorer, {key, salt, level, acc}, &1))

        acc * skeleton.fanout + digit
      end)

    if index < tuple_size(skeleton.clusters) do
      cluster = elem(skeleton.clusters, index)
      Enum.max_by(cluster, fn node -> mod.score(scorer, {key, salt, index}, node) end)
    else
      do_owner(key, skeleton, salt + 1)
    end
  end

  defp chunk_redistribute(nodes, size) do
    # Deterministic ordering so the same node set always produces the same clusters.
    chunks =
      nodes
      |> Enum.sort()
      |> Enum.dedup()
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

  defp optimal_fanout(1), do: 2

  defp optimal_fanout(cluster_count) do
    Enum.min_by(2..8, fn fanout ->
      levels = ceil(:math.log(cluster_count) / :math.log(fanout))
      capacity = Integer.pow(fanout, levels)
      overflow_prob = (capacity - cluster_count) / capacity
      fanout * levels / (1 - overflow_prob)
    end)
  end

  defp compute_branch_weights(_clusters, _fanout, 0), do: {}

  defp compute_branch_weights(clusters, fanout, levels) do
    cluster_weights =
      clusters
      |> Enum.with_index()
      |> Enum.map(fn {nodes, index} ->
        total =
          Enum.sum(
            Enum.map(nodes, fn
              {_node, weight} -> weight
              # plain nodes get implicit weight 1
              _ -> 1
            end)
          )

        {index, total}
      end)

    0..(levels - 1)
    |> Enum.map(fn level ->
      divisor = Integer.pow(fanout, levels - level - 1)

      Enum.reduce(cluster_weights, %{}, fn {index, weight}, acc ->
        Map.update(acc, div(index, divisor), weight, &(&1 + weight))
      end)
    end)
    |> List.to_tuple()
  end
end

defimpl Inspect, for: HRW.Skeleton do
  def inspect(%HRW.Skeleton{clusters: clusters, fanout: fanout, scorer: scorer}, _opts) do
    nodes =
      clusters
      |> Tuple.to_list()
      |> Enum.reduce(0, fn cluster, acc -> acc + length(cluster) end)

    label = if nodes == 1, do: "node", else: "nodes"
    "#HRW.Skeleton<#{nodes} #{label}, fanout: #{fanout}, scorer: #{inspect(scorer)}>"
  end
end
