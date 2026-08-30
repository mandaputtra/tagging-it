defmodule TaggingItWeb.Router do
  use TaggingItWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TaggingItWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TaggingItWeb do
    pipe_through :browser

    live "/", LandingLive

    # PROTOTYPE — label print flow exploration (#9). Throwaway; delete after verdict.
    get "/prototype/print", PrintPrototypeController, :show
    # PROTOTYPE — symbology-first home exploration (#15). Throwaway; delete after verdict.
    get "/prototype/home", HomePrototypeController, :show
    # PROTOTYPE — scan + verified flow (#21). Throwaway; delete after verdict.
    get "/prototype/scan", ScanPrototypeController, :show

    # Real SheetView print flow — batch data arrives from the browser store.
    live "/sheet/:batch_id", SheetLive
    live "/batches/new", ChooseTypeLive
    live "/batches/new/:symbology", BatchFormLive
    live "/batches/:batch_id", BatchDetailLive
    live "/scan", ScanLive
    live "/verified/:code_id", VerifiedLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", TaggingItWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tagging_it, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TaggingItWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
