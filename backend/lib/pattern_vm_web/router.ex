defmodule PatternVMWeb.Router do
  use PatternVMWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PatternVMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PatternVMWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api", PatternVMWeb.API do
    pipe_through :api

    resources "/patterns", PatternController, except: [:new, :edit]
    resources "/workflows", WorkflowController, except: [:new, :edit]
    post "/interact", InteractionController, :interact
    post "/workflows/:name/execute", WorkflowController, :execute
    get "/visualization", VisualizationController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pattern_vm, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PatternVMWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
