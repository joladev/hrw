nodes_tiny = Enum.map(1..10, fn i -> "key-#{i}" end)
nodes_small = Enum.map(1..100, fn i -> "key-#{i}" end)
nodes_medium = Enum.map(1..1000, fn i -> "key-#{i}" end)
nodes_large = Enum.map(1..10000, fn i -> "key-#{i}" end)

Benchee.run(%{
  "owner 100 vnodes" => fn %{nodes: nodes} -> HRW.owner("test", nodes, vnodes: 100) end,
  "owner no vnodes" => fn %{nodes: nodes} -> HRW.owner("test", nodes, vnodes: 1) end,
  "skeleton pre-built" => fn %{skeleton: skeleton} -> HRW.Skeleton.owner("test", skeleton) end,
  "skeleton every" => fn %{nodes: nodes} -> skeleton = HRW.Skeleton.build(nodes); HRW.Skeleton.owner("test", skeleton) end
}, inputs: %{
  "tiny" => %{
    nodes: nodes_tiny,
    skeleton: HRW.Skeleton.build(nodes_tiny)
  },
  "small" => %{
    nodes: nodes_small,
    skeleton: HRW.Skeleton.build(nodes_small)
  },
  "medium" => %{
    nodes: nodes_medium,
    skeleton: HRW.Skeleton.build(nodes_medium)
  },
  "large" => %{
    nodes: nodes_large,
    skeleton: HRW.Skeleton.build(nodes_large)
  },
})
