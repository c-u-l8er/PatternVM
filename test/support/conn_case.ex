defmodule PatternVMWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint PatternVMWeb.Endpoint

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PatternVMWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
