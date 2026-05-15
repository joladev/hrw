defmodule HRW.Weighted do
  @moduledoc """
  Weighted HRW implementation for ensuring certain nodes get a greater share of keys.

  Inspired by https://www.ietf.org/archive/id/draft-ietf-bess-weighted-hrw-00.html

  Works with both flat lists (`HRW.owner(key, [{"a", 1}, {"b", 4}], scorer: %HRW.Weighted{})`)
  and skeletons (`HRW.build([...], scorer: %HRW.Weighted{})`).
  """

  @behaviour HRW.Scorer

  import Bitwise

  @phash2_max 0x7FFFFFF

  defstruct [:hash_fn, :branch_weights, :fanout]

  @type t :: %__MODULE__{
          hash_fn: (term() -> integer()) | nil,
          branch_weights: tuple() | nil,
          fanout: pos_integer() | nil
        }

  @impl HRW.Scorer
  def score(%__MODULE__{hash_fn: nil}, key, {node, weight}) do
    hash = :erlang.phash2({key, node})
    leaf_score(hash, weight)
  end

  def score(%__MODULE__{hash_fn: hash_fn}, key, {node, weight}) do
    hash = hash_fn.({key, node})
    leaf_score(hash, weight)
  end

  # Skeleton tree walk: key is {real_key, salt, level, prefix},
  # entry is the candidate digit. Looks up branch weight from precomputed tree.
  def score(
        %__MODULE__{branch_weights: branch_weights, fanout: fanout},
        {key, salt, level, prefix},
        digit
      ) do
    candidate = prefix * fanout + digit

    branch_weight =
      branch_weights
      |> elem(level)
      |> Map.get(candidate, 0)

    if branch_weight == 0 do
      # Empty branch (no nodes under this prefix). Returning 0.0 ensures it never wins.
      0.0
    else
      normalized_hash =
        (:erlang.phash2({key, salt, level, prefix, digit}) &&& @phash2_max) / @phash2_max

      :math.pow(normalized_hash, 1 / branch_weight)
    end
  end

  defp leaf_score(hash, weight) do
    normalized = (hash &&& @phash2_max) / @phash2_max
    :math.pow(normalized, 1 / weight)
  end
end
