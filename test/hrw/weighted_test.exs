defmodule HRWWeightedTest do
  use ExUnit.Case, async: true
  alias HRW.Weighted

  test "higher weight nodes win more often in flat lists" do
    # 80% of the time, the node with weight 4 wins vs weight 1
    weights = [{"heavy", 4}, {"light", 1}]
    keys = Enum.map(1..1_000, &"key-#{&1}")

    winners =
      keys
      |> Enum.map(&HRW.owner(&1, weights, scorer: %Weighted{}))
      |> Enum.frequencies()

    assert winners["heavy"] > winners["light"]
  end

  test "weight ratio approximates win ratio at scale" do
    keys = Enum.map(1..100, &"key-#{&1}")
    weights = [{"a", 3}, {"b", 1}]

    results =
      keys
      |> Enum.map(&HRW.owner(&1, weights, scorer: %Weighted{}))
      |> Enum.frequencies()

    # b wins ~1/4 of the time, a wins ~3/4 (roughly proportional to weight ratio 3:1)
    total = results["a"] + results["b"]
    ratio = results["a"] / total

    # Expect a to win roughly 75% of the time; allow ±15% noise
    assert ratio >= 0.60 and ratio <= 0.90
  end

  test "weighted skeleton routing matches weight ratios" do
    nodes = [{"a", 3}, {"b", 2}, {"c", 1}]
    skeleton = HRW.build(nodes, scorer: %Weighted{})

    keys = Enum.map(1..500, &"key-#{&1}")

    results =
      keys
      |> Enum.map(&HRW.owner(&1, skeleton))
      |> Enum.frequencies()

    total = results["a"] + results["b"] + results["c"]
    a_ratio = results["a"] / total

    # alpha has weight 3, total weight 6 → 50% of traffic
    assert a_ratio >= 0.40 and a_ratio <= 0.60
  end

  test "weighted skeleton handles configurations with empty branches" do
    nodes = Enum.map(1..100, fn i -> {"node#{i}", 1} end)
    sk = HRW.build(nodes, scorer: %HRW.Weighted{}, fanout: 2, cluster_size: 15)
    # capacity 8, 6 clusters, 2 empty slots

    keys = Enum.map(1..10_000, fn i -> "key-#{i}" end)
    results = Enum.map(keys, &HRW.owner(&1, sk))
    assert Enum.all?(results, &is_binary/1)
    assert length(Enum.uniq(results)) > 90
  end
end
