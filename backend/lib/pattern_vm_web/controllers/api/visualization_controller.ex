defmodule PatternVMWeb.API.VisualizationController do
  use PatternVMWeb, :controller

  def index(conn, _params) do
    # Get visualization data - would need to be implemented
    visualization = PatternVM.get_visualization_data()
    json(conn, visualization)
  end
end
