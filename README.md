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

## Quickstart

```elixir
def deps do
  [
    {:hrw, "~> 0.2"}
  ]
end
```

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

Operating System: macOS
CPU Information: Apple M4 Pro
Number of Available Cores: 14
Available memory: 24 GB
Elixir 1.19.5
Erlang 28.5
JIT enabled: true

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 0 ns
reduction time: 0 ns
parallel: 1
inputs: A: 10, B: 100, C: 1_000, D: 10_000
Estimated total run time: 2 min 20 s
Excluding outliers: false

##### With input A: 10 #####
Name                                    ips        average  deviation         median         99th %
HRW.owner (skeleton)                 3.12 M      320.82 ns  ±1135.15%         292 ns         417 ns
ExHashRing.Ring.find_node            2.83 M      353.87 ns  ±1416.30%         333 ns         459 ns
HRW.owner                            1.77 M      563.81 ns   ±851.98%         541 ns         750 ns
HRW.owner (skeleton weighted)        1.43 M      700.90 ns   ±673.15%         667 ns         958 ns
HRW.owner (weighted)                 0.97 M     1026.51 ns   ±727.94%        1000 ns        1333 ns

Comparison:
HRW.owner (skeleton)                 3.12 M
ExHashRing.Ring.find_node            2.83 M - 1.10x slower +33.05 ns
HRW.owner                            1.77 M - 1.76x slower +242.99 ns
HRW.owner (skeleton weighted)        1.43 M - 2.18x slower +380.08 ns
HRW.owner (weighted)                 0.97 M - 3.20x slower +705.70 ns

##### With input B: 100 #####
Name                                    ips        average  deviation         median         99th %
ExHashRing.Ring.find_node         2719.45 K        0.37 μs   ±471.36%        0.33 μs        0.50 μs
HRW.owner (skeleton)              1081.75 K        0.92 μs   ±539.84%        0.92 μs        1.21 μs
HRW.owner (skeleton weighted)      581.44 K        1.72 μs   ±246.47%        1.67 μs        2.33 μs
HRW.owner                          161.41 K        6.20 μs    ±77.88%        6.21 μs        8.29 μs
HRW.owner (weighted)                92.70 K       10.79 μs    ±17.28%       10.88 μs       14.83 μs

Comparison:
ExHashRing.Ring.find_node         2719.45 K
HRW.owner (skeleton)              1081.75 K - 2.51x slower +0.56 μs
HRW.owner (skeleton weighted)      581.44 K - 4.68x slower +1.35 μs
HRW.owner                          161.41 K - 16.85x slower +5.83 μs
HRW.owner (weighted)                92.70 K - 29.33x slower +10.42 μs

##### With input C: 1_000 #####
Name                                    ips        average  deviation         median         99th %
ExHashRing.Ring.find_node         2440.68 K        0.41 μs  ±1510.90%        0.38 μs        0.54 μs
HRW.owner (skeleton)               791.96 K        1.26 μs   ±501.63%        1.21 μs        1.63 μs
HRW.owner (skeleton weighted)      444.13 K        2.25 μs   ±244.08%        2.25 μs           3 μs
HRW.owner                           14.14 K       70.74 μs    ±14.97%       70.67 μs       88.38 μs
HRW.owner (weighted)                 8.23 K      121.51 μs     ±7.76%      121.13 μs      143.54 μs

Comparison:
ExHashRing.Ring.find_node         2440.68 K
HRW.owner (skeleton)               791.96 K - 3.08x slower +0.85 μs
HRW.owner (skeleton weighted)      444.13 K - 5.50x slower +1.84 μs
HRW.owner                           14.14 K - 172.64x slower +70.33 μs
HRW.owner (weighted)                 8.23 K - 296.56x slower +121.10 μs

##### With input D: 10_000 #####
Name                                    ips        average  deviation         median         99th %
ExHashRing.Ring.find_node         2065.21 K        0.48 μs  ±1355.23%        0.42 μs        0.63 μs
HRW.owner (skeleton)               656.42 K        1.52 μs   ±939.75%        1.46 μs        1.96 μs
HRW.owner (skeleton weighted)      342.75 K        2.92 μs   ±299.96%        2.75 μs        3.92 μs
HRW.owner                            1.40 K      714.56 μs     ±5.92%      711.25 μs      840.38 μs
HRW.owner (weighted)                 0.80 K     1257.34 μs     ±4.38%     1253.08 μs     1434.77 μs

Comparison:
ExHashRing.Ring.find_node         2065.21 K
HRW.owner (skeleton)               656.42 K - 3.15x slower +1.04 μs
HRW.owner (skeleton weighted)      342.75 K - 6.03x slower +2.43 μs
HRW.owner                            1.40 K - 1475.73x slower +714.08 μs
HRW.owner (weighted)                 0.80 K - 2596.68x slower +1256.86 μs

Reproduce with `elixir benches/bench.exs`.
