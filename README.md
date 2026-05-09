# HRW

HRW (Highest Random Weight) is another name for rendezvous hashing, an alternative to consistent hashing frequently used in programming to get stable association of keys and nodes that are resistant to changes in the list of nodes.

The most common library in the Elixir community to use to solve that problem is ExHashRing by Discord, which is battle-tested and highly performant. However, it requires starting and maintaining processes, and HRW does not. For smaller lists of nodes, `HRW.owner` (O(n)) or `HRW.owners` (O(n log n)) will perform just fine, and is completely stateless, requiring no setup when starting your app.

This library also comes with HRW.Skeleton which uses a clustering mechanism to go from O(n) to O(log n), with the trade-off that you need to create the struct with `HRW.Skeleton.build` and pass to each call of `HRW.Skeleton.owner`.

Additionally, there's `HRW.Bounded` for when you want to control the distribution of keys across nodes to limit skew. Consistent hashing and rendezvous hashing algorithms can easily result in uneven distribution for smaller node counts, and `HRW.Bounded` lets you control that, assuming that you have the whole key set up front.

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

# HRW.Bounded
HRW.Bounded.assignments(["a", "b", "c", "d"], ["x", "y"], epsilon: 0.0)
#=> %{"a" => "x", "b" => "x", "c" => "y", "d" => "y"}
```

## Benchmarks

tl;dr HRW performs similarly to ExHashRing on smaller node lists, but falls behind as the node list grows. HRW.Skeleton offsets some of the issues, but doesn't match ExHashRing.

Lookup latency on Apple M4 Pro / Elixir 1.19.5 / OTP 28.5, median per call:

| nodes  | HRW.owner   | HRW.Skeleton.owner | ExHashRing.find_node |
|-------:|------------:|-------------------:|---------------------:|
|     10 |     292 ns  |      292 ns        |        333 ns        |
|    100 |    2.67 µs  |      875 ns        |        375 ns        |
|  1,000 |   25.54 µs  |     1.08 µs        |        380 ns        |
| 10,000 |  253.58 µs  |     1.38 µs        |        420 ns        |

Reproduce with `elixir benches/hrw.exs`.
