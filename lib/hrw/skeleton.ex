defmodule HRW.Skeleton do
  defstruct [:clusters, :fanout, :levels]

  def build(nodes, opts \\ []) do
    fanout = Keyword.get(opts, :fanout, 3)
    size = Keyword.get(opts, :cluster_size, 16)

    %__MODULE__{
      # Grouping into clusters is what makes this O(log n) instead of O(n).
      # After the virtual tree picks one cluster, we only hash ~16 real nodes.
      clusters: chunk_redistribute(nodes, size),
      fanout: fanout,
      # Each level produces one base-fanout digit. We need enough digits
      # that fanout^levels >= cluster_count, or some clusters are unreachable.
      levels: ceil(:math.log(max(length(nodes), 1)) / :math.log(fanout))
    }
  end

  def owner(key, %__MODULE__{} = skeleton, opts \\ []) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)
    do_owner(key, skeleton, 0, hash_fn)
  end

  defp do_owner(_key, %__MODULE__{clusters: []}, _salt, _hash_fn), do: nil

  defp do_owner(key, %__MODULE__{clusters: [cluster]}, _salt, hash_fn) do
    Enum.max_by(cluster, fn node -> hash_fn.({key, node}) end)
  end

  defp do_owner(key, skeleton, salt, hash_fn) do
    # At each level we run HRW on virtual children — not real nodes —
    # to pick which branch of the tree to follow.
    path =
      Enum.map_join(0..(skeleton.levels - 1), fn level ->
        Enum.max_by(0..(skeleton.fanout - 1), fn child ->
          hash_fn.({key, salt, level, child})
        end)
        |> Integer.to_string()
      end)

    # The path digits form a base-fanout number. That number *is* the cluster index.
    # No tree structure is stored — the virtual nodes are generated on the fly from the path.
    index = String.to_integer(path, skeleton.fanout)

    case Enum.at(skeleton.clusters, index) do
      # When cluster_count is not a perfect power of fanout, some paths are dead ends.
      # Salt perturbs the hashes so the retry generates a completely different path.
      nil ->
        do_owner(key, skeleton, salt + 1, hash_fn)

      [] ->
        do_owner(key, skeleton, salt + 1, hash_fn)

      cluster ->
        # The virtual tree got us to a cluster. Standard HRW on ~16 nodes
        # instead of all n — this is where the speedup comes from.
        Enum.max_by(cluster, fn node -> hash_fn.({key, salt, path, node}) end)
    end
  end

  defp chunk_redistribute(nodes, size) do
    # Deterministic ordering so the same node set always produces the same clusters.
    chunks = nodes |> Enum.uniq() |> Enum.sort() |> Enum.chunk_every(size)

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
