Mix.install([
  {:hrw, path: Path.expand("..", __DIR__)},
  {:benchee, "~> 1.5"},
  {:ex_hash_ring, "~> 7.0"}
])

alias ExHashRing.Ring

setup = fn n ->
  nodes = Enum.map(1..n, &"node-#{&1}")
  {:ok, ring} = Ring.start_link()
  Ring.set_nodes(ring, nodes, :infinity)
  %{nodes: nodes, skeleton: HRW.Skeleton.build(nodes), ring: ring}
end

Benchee.run(%{
  "HRW.owner" => fn %{nodes: nodes} -> HRW.owner("test", nodes) end,
  "HRW.Skeleton.owner" => fn %{skeleton: skeleton} -> HRW.Skeleton.owner("test", skeleton) end,
  "ExHashRing.Ring.find_node" => fn %{ring: ring} -> Ring.find_node(ring, "test") end
}, inputs: %{
  "tiny" => setup.(10),
  "small" => setup.(100),
  "medium" => setup.(1_000),
  "large" => setup.(10_000),
})
