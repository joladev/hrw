defmodule HRW.BoundedTest do
  use ExUnit.Case, async: true
  doctest HRW.Bounded

  test "assignments respect the cap, giving exact balance with epsilon: 0.0" do
    keys = ["a", "b", "c", "d"]
    nodes = ["x", "y"]

    counts =
      keys
      |> HRW.Bounded.assignments(nodes, epsilon: 0.0)
      |> Map.values()
      |> Enum.frequencies()

    assert counts == %{"x" => 2, "y" => 2}
  end
end
