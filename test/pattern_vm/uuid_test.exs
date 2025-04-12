defmodule PatternVM.UUIDTest do
  use ExUnit.Case

  test "generates unique UUIDs" do
    # Since we're in test mode, it should generate predictable UUIDs
    uuid1 = PatternVM.UUID.uuid4()
    uuid2 = PatternVM.UUID.uuid4()

    assert is_binary(uuid1)
    assert is_binary(uuid2)
    assert uuid1 != uuid2

    # Test UUIDs should have a specific format
    assert String.match?(uuid1, ~r/test-uuid-\d+/)
    assert String.match?(uuid2, ~r/test-uuid-\d+/)
  end
end
