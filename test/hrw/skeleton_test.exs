defmodule HRW.SkeletonTest do
  use ExUnit.Case, async: true

  test "owner routes a key to a node via the virtual tree" do
    nodes = Enum.map(1..12, &"server#{&1}")
    skeleton = HRW.build(nodes, cluster_size: 4)

    assert HRW.owner("192.168.0.1", skeleton) == "server9"
  end
end
