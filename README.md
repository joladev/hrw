# HRW

HRW (Highest Random Weight) is another name for rendezvous hashing, an alternative to consistent hashing frequently used in programming to get stable association of keys and nodes that are resistant to changes in the list of nodes.

The most common library in the Elixir community to use to solve that problem is ExHashRing by Discord, which is battle-tested and highly performant. However, it requires starting and maintaining processes, and HRW does not. For smaller lists of nodes, `HRW.owner` (O(n)) or `HRW.owners` (O(n log n)) will perform just fine, and is completely stateless, requiring no setup when starting your app.

This library also comes with HRW.Skeleton which uses a clustering mechanism to go from O(n) to O(log n), with the trade-off that you need to create the struct with `HRW.Skeleton.build` and pass to each call of `HRW.Skeleton.owner`.

```elixir
# HRW
HRW.owner("192.168.0.1", ["server1", "server2", "server3"])
#=> "server2"

HRW.owners("192.168.0.1", ["server1", "server2", "server3"], 2)
#=> ["server2", "server3"]

# HRW.Skeleton
skeleton = HRW.Skeleton.build(["server1", "server2", "server3"])
#=> #HRW.Skeleton<3 nodes, fanout: 3>

HRW.Skeleton.owner("192.168.0.2", skeleton)
#=> "server3"
```
