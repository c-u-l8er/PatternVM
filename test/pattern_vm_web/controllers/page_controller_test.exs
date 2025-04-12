defmodule PatternVMWeb.PageControllerTest do
  use PatternVMWeb.ConnCase

  @tag :phoenix_controller
  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "PatternVM"
  end
end
