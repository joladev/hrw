# HRW

[![Hex.pm](https://img.shields.io/hexpm/v/hrw.svg)](https://hex.pm/packages/hrw)
[![Hexdocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/hrw)
[![CI](https://github.com/joladev/hrw/actions/workflows/ci.yml/badge.svg)](https://github.com/joladev/hrw/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/hexpm/l/hrw.svg)](https://github.com/joladev/hrw/blob/main/LICENSE)

HRW (Highest Random Weight) is another name for rendezvous hashing, an alternative to consistent hashing frequently used in programming to get stable association of keys and nodes that are resistant to changes in the list of nodes.

The most common library in the Elixir community to use to solve that problem is ExHashRing by Discord, which is battle-tested and highly performant. However, it requires starting and maintaining processes, and HRW does not. For smaller lists of nodes, `HRW.owner` (O(n)) or `HRW.owners` (O(n log n)) will perform just fine, and is completely stateless, requiring no setup when starting your app.

For larger node sets, build a skeleton with `HRW.build` and pass it to `HRW.owner` to get O(log n) lookups. The skeleton is plain data — build it once, reuse it across calls.

`HRW.owner` and `HRW.build` support an optional `scorer` option for alternative strategies. The available options are `%HRW{}` for the default algorithm, and `%HRW.Weighted{}` for when you want certain nodes to get a larger share of keys.

For additional strategies, there's `HRW.Bounded` for when you want to control the distribution of keys across nodes to limit skew. Consistent hashing and rendezvous hashing algorithms can easily result in uneven distribution for smaller node counts, and `HRW.Bounded` lets you control that, assuming that you have the whole key set up front.

```elixir
# HRW
HRW.owner("192.168.0.1", ["server1", "server2", "server3"])
#=> "server2"

HRW.owners("192.168.0.1", ["server1", "server2", "server3"], 2)
#=> ["server2", "server3"]

# Skeleton-backed lookup for large node sets
skeleton = HRW.build(["server1", "server2", "server3"])
#=> #HRW.Skeleton<3 nodes, fanout: 3, scorer: %HRW{hash_fn: nil}>

HRW.owner("192.168.0.2", skeleton)
#=> "server3"

# HRW.Weighted
HRW.owner("192.168.0.1", [{"server1", 1}, {"server2", 1}, {"server3", 10}], scorer: %HRW.Weighted{})
#=> "server3"

# HRW.Bounded
HRW.Bounded.assignments(["a", "b", "c", "d"], ["x", "y"], epsilon: 0.0)
#=> %{"a" => "x", "b" => "x", "c" => "y", "d" => "y"}
```

## Benchmarks

tl;dr HRW performs similarly to ExHashRing on smaller node lists, but falls behind as the node list grows. HRW.Skeleton offsets some of the issues, but doesn't match ExHashRing.

Lookup latency on Apple M4 Pro / Elixir 1.19.5 / OTP 28.5, median per call:

| nodes  | HRW.owner | HRW.owner (weighted) | HRW.owner (skeleton) | HRW.owner (skeleton weighted) | ExHashRing.find_node |
|-------:|----------:|---------------------:|---------------------:|------------------------------:|---------------------:|
|     10 |    542 ns |              1.00 µs |               292 ns |                        667 ns |               333 ns |
|    100 |   6.33 µs |             11.00 µs |               920 ns |                       1.71 µs |               380 ns |
|  1,000 |  71.79 µs |               121 µs |              1.25 µs |                       2.25 µs |               380 ns |
| 10,000 |    771 µs |              1.25 ms |              1.50 µs |                       2.92 µs |               420 ns |

Reproduce with `elixir benches/bench.exs`.
