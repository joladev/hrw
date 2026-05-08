defmodule HRWTest do
  use ExUnit.Case, async: true
  doctest HRW

  test "owner returns the highest-weight node for a key" do
    assert HRW.owner("192.168.0.1", ["server1", "server2", "server3"]) == "server2"
  end

  test "owners returns the top-k nodes in descending weight order" do
    assert HRW.owners("192.168.0.1", ["server1", "server2", "server3"], 2) ==
             ["server2", "server3"]
  end
end
