defmodule SocialScribeWeb.LandingLiveTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "mounts landing page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Turn meetings into"
      assert html =~ "actionable content"
      assert html =~ "Get Started with Google"
    end
  end
end
