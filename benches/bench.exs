Mix.install([
  {:hrw, path: Path.expand("..", __DIR__)},
  {:benchee, "~> 1.5"},
  {:ex_hash_ring, "~> 7.0"}
])

alias ExHashRing.Ring

defmodule Bench do
  def run do
    setup = fn n ->
      nodes = Enum.map(1..n, &"node-#{&1}")
      {:ok, ring} = Ring.start_link()
      Ring.set_nodes(ring, nodes, :infinity)
      %{nodes: nodes, skeleton: HRW.build(nodes), ring: ring, weighted_nodes: Enum.map(1..n, &{"node-#{&1}", &1}), weighted_skeleton: HRW.build(Enum.map(1..n, &{"node-#{&1}", &1}), scorer: %HRW.Weighted{})}
    end

    Benchee.run(%{
      "HRW.owner" => fn %{nodes: nodes} -> HRW.owner("test", nodes) end,
      "HRW.owner (weighted)" => fn %{weighted_nodes: weighted_nodes} -> HRW.owner("test", weighted_nodes, scorer: %HRW.Weighted{}) end,
      "HRW.owner (skeleton)" => fn %{skeleton: skeleton} -> HRW.owner("test", skeleton) end,
      "HRW.owner (skeleton weighted)" => fn %{weighted_skeleton: weighted_skeleton} -> HRW.owner("test", weighted_skeleton) end,
      "ExHashRing.Ring.find_node" => fn %{ring: ring} -> Ring.find_node(ring, "test") end
    }, inputs: %{
      "A: 10" => setup.(10),
      "B: 100" => setup.(100),
      "C: 1_000" => setup.(1_000),
      "D: 10_000" => setup.(10_000)
    })
  end
end

Bench.run()
