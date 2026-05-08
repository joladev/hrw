defmodule HRW.SkeletonTest do
  use ExUnit.Case, async: true
  doctest HRW.Skeleton

  test "owner routes a key to a node via the virtual tree" do
    nodes = Enum.map(1..12, &"server#{&1}")
    skeleton = HRW.Skeleton.build(nodes, cluster_size: 4)

    assert HRW.Skeleton.owner("192.168.0.1", skeleton) == "server12"
  end
end
