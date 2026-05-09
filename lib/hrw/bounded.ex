defmodule HRW.Bounded do
  @moduledoc """
  A bounded-load variant of HRW. Distributes a known set of keys across nodes
  such that no node receives more than `ceil(|keys| / |nodes| × (1 + epsilon))`
  keys.

  Pure function of `(keys, nodes, opts)` — any two callers with the same
  inputs produce the same assignment, no coordination required. Use this
  when the full key set is known at compute time and you want bounded skew.
  """

  @doc """
  Returns a map of `key => node` covering every input key. Returns `%{}`
  when `keys` is empty.

  Each key is assigned to its highest-scoring node, with overflow falling
  through to the next-best when a node hits the cap of
  `ceil(|keys| / |nodes| × (1 + epsilon))`.

  ## Options

    * `:epsilon` - load slack factor. Smaller values give tighter balance but
      more movement on node churn. Defaults to `0.25`.
    * `:hash_fn` - a function `term -> integer`. Defaults to `&:erlang.phash2/1`.

  ## Examples

      iex> HRW.Bounded.assignments(["a", "b", "c", "d"], ["x", "y"], epsilon: 0.0)
      %{"a" => "x", "b" => "x", "c" => "y", "d" => "y"}
  """
  @spec assignments([term()], [term()], keyword()) :: %{term() => term()}
  def assignments(keys, nodes, opts \\ [])

  def assignments(_keys, [], _opts) do
    raise ArgumentError, "HRW.Bounded.assignments/3 requires a non-empty list of nodes"
  end

  def assignments(keys, nodes, opts) do
    hash_fn = Keyword.get(opts, :hash_fn, &:erlang.phash2/1)
    epsilon = Keyword.get(opts, :epsilon, 0.25)

    if epsilon < 0 do
      raise ArgumentError,
            "HRW.Bounded.assignments/3 requires :epsilon >= 0, got: #{inspect(epsilon)}"
    end

    keys =
      keys
      |> Enum.uniq()
      |> Enum.sort()

    nodes =
      nodes
      |> Enum.uniq()
      |> Enum.sort()

    cap = ceil(length(keys) / length(nodes) * (1 + epsilon))

    {results, _} =
      Enum.reduce(keys, {%{}, %{}}, fn k, {out, load} ->
        node =
          nodes
          |> Enum.filter(fn n -> Map.get(load, n, 0) < cap end)
          |> Enum.max_by(fn n -> hash_fn.({k, n}) end)

        {Map.put(out, k, node), Map.update(load, node, 1, &(&1 + 1))}
      end)

    results
  end
end
