defmodule SocialScribeWeb.Components.UI.SkeletonTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule SkeletonTextTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:lines, session["lines"] || 3)}
    end

    def render(assigns) do
      ~H"""
      <.skeleton_text lines={@lines} />
      """
    end
  end

  defmodule SkeletonTableTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:rows, session["rows"] || 2)
       |> Phoenix.LiveView.Utils.assign(:columns, session["columns"] || 3)}
    end

    def render(assigns) do
      ~H"""
      <.skeleton_table rows={@rows} columns={@columns} />
      """
    end
  end

  defmodule SkeletonListTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:items, session["items"] || 2)}
    end

    def render(assigns) do
      ~H"""
      <.skeleton_list items={@items} />
      """
    end
  end

  defmodule SkeletonTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.skeleton class="h-4 w-[250px]" />
      <.skeleton_card />
      """
    end
  end

  describe "UI.Skeleton" do
    test "renders skeleton and skeleton_card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, SkeletonTestLive, [])

      assert html =~ "animate-pulse"
    end

    test "skeleton_text renders lines", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SkeletonTextTestLive, session: %{"lines" => 2})

      assert html =~ "animate-pulse"
      assert html =~ "rounded"
    end

    test "skeleton_table renders rows and columns", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SkeletonTableTestLive,
          session: %{"rows" => 2, "columns" => 3}
        )

      assert html =~ "animate-pulse"
      assert html =~ "rounded"
    end

    test "skeleton_list renders items", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, SkeletonListTestLive, session: %{"items" => 3})

      assert html =~ "animate-pulse"
      assert html =~ "rounded"
    end
  end
end
