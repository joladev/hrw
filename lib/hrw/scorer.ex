defmodule HRW.Scorer do
  @moduledoc """
  Behaviour for HRW scoring strategies. Each variant module (`HRW`, future
  `HRW.Weighted`, etc.) defines a struct holding its configuration and
  implements `score/3` returning a score for a `(key, node)` pair.

  Pass an instance via the `:scorer` option to `HRW.owner/3`, `HRW.owners/4`,
  or `HRW.build/2`. The highest-scoring node wins.
  """

  @callback score(scorer :: struct(), key :: term(), node :: term()) :: number()
end
