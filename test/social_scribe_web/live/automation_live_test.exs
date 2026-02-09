defmodule SocialScribeWeb.AutomationLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AutomationsFixtures
  import SocialScribe.AccountsFixtures

  @create_attrs %{
    name: "some name <> #{System.unique_integer()}",
    description: "some description",
    platform: :facebook,
    example: "some example"
  }
  @update_attrs %{
    name: "some updated name",
    description: "some updated description",
    platform: :facebook,
    example: "some updated example"
  }
  @invalid_attrs %{
    name: nil,
    description: nil,
    platform: :linkedin,
    example: nil
  }

  defp create_automation(%{conn: conn}) do
    user = user_fixture()
    automation = automation_fixture(%{user_id: user.id, is_active: false})

    %{conn: log_in_user(conn, user), automation: automation}
  end

  describe "Index" do
    setup [:create_automation]

    test "lists all automations", %{conn: conn, automation: automation} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/automations")

      assert html =~ "Listing Automations"
      assert html =~ automation.name
    end

    test "saves new automation", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live |> element("a", "New Automation") |> render_click() =~
               "New Automation"

      assert_patch(index_live, ~p"/dashboard/automations/new")

      assert index_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#automation-form", automation: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/automations")

      html = render(index_live)
      assert html =~ "Automation created successfully"
      assert html =~ "some description"
    end

    test "cannot toggle automation if it is already active", %{conn: conn, automation: automation} do
      _automation_2 =
        automation_fixture(%{
          user_id: automation.user_id,
          platform: automation.platform,
          is_active: true
        })

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live
             |> element("#automations-#{automation.id} input[phx-click='toggle_automation']")
             |> render_click() =~ "You can only have one active automation per platform"
    end

    test "updates automation in listing", %{conn: conn, automation: automation} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      assert index_live
             |> element("#automations-#{automation.id} a[data-phx-link='patch']")
             |> render_click() =~
               "Edit Automation"

      assert_patch(index_live, ~p"/dashboard/automations/#{automation}/edit")

      assert index_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#automation-form", automation: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/dashboard/automations")

      html = render(index_live)
      assert html =~ "Automation updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes automation in listing", %{conn: conn, automation: automation} do
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations")

      # The delete button is an icon button with data-confirm
      assert index_live
             |> element(
               "#automations-#{automation.id} a[data-confirm='Are you sure you want to delete this automation?']"
             )
             |> render_click()

      refute has_element?(index_live, "#automations-#{automation.id}")
    end
  end

  describe "Show" do
    setup [:create_automation]

    test "displays automation", %{conn: conn, automation: automation} do
      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert html =~ "Show Automation"
      assert html =~ automation.name
    end

    test "cannot toggle automation if it is already active", %{conn: conn, automation: automation} do
      _automation_2 =
        automation_fixture(%{
          user_id: automation.user_id,
          platform: automation.platform,
          is_active: true
        })

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert index_live
             |> element("input[phx-click='toggle_automation']")
             |> render_click() =~ "You can only have one active automation per platform"
    end

    test "updates automation within modal", %{conn: conn, automation: automation} do
      {:ok, show_live, _html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Automation"

      assert_patch(show_live, ~p"/dashboard/automations/#{automation}/show/edit")

      assert show_live
             |> form("#automation-form", automation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#automation-form", automation: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/dashboard/automations/#{automation}")

      html = render(show_live)
      assert html =~ "Automation updated successfully"
      assert html =~ "some updated name"
    end

    test "renders markdown in example section on show page", %{
      conn: conn,
      automation: _automation
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      automation =
        automation_fixture(%{
          user_id: user.id,
          example: "# Example Heading\n\nThis is **bold** and *italic* text"
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      # Check that markdown is rendered as HTML (Earmark adds newlines)
      assert html =~ ~s(<h1>)
      assert html =~ "Example Heading"
      assert html =~ ~s(</h1>)
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
      assert html =~ "markdown-content"
    end

    test "renders markdown links in example section", %{conn: conn, automation: _automation} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      automation =
        automation_fixture(%{
          user_id: user.id,
          example: "Check out [this link](https://example.com)"
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert html =~ ~s(href="https://example.com")
      assert html =~ "this link"
      assert html =~ "markdown-content"
    end

    test "renders markdown code blocks in example section", %{conn: conn, automation: _automation} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      automation =
        automation_fixture(%{
          user_id: user.id,
          example: "```elixir\ndef hello, do: :world\n```"
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert html =~ "<pre"
      assert html =~ "<code"
      assert html =~ "def hello, do: :world"
      assert html =~ "markdown-content"
    end

    test "renders complex markdown with multiple elements in example", %{
      conn: conn,
      automation: _automation
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      automation =
        automation_fixture(%{
          user_id: user.id,
          example: """
          # Title

          Paragraph with **bold** and *italic*.

          - List item 1
          - List item 2

          `code` and [link](https://example.com)
          """
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/automations/#{automation}")

      assert html =~ ~s(<h1>)
      assert html =~ "Title"
      assert html =~ ~s(</h1>)
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
      assert html =~ "<ul>"
      assert html =~ "<code"
      assert html =~ "code"
      assert html =~ ~s(href="https://example.com")
      assert html =~ "markdown-content"
    end
  end
end
