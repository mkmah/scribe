defmodule SocialScribeWeb.UserSettingsSalesforceTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures

  describe "Settings page - Salesforce section" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "shows Connect Salesforce button when no credential", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "h3", "Salesforce")
      assert has_element?(view, "a", "Connect Salesforce")
    end

    test "shows connected Salesforce account when credential exists", %{
      conn: conn,
      user: user
    } do
      _cred =
        salesforce_credential_fixture(%{
          user_id: user.id,
          uid: "sf_org_123",
          email: "sf_user@example.com"
        })

      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "p", "Contacts, opportunities & notes")
      # Template shows email || uid, so when email exists, only email is displayed
      assert has_element?(view, "p", "sf_user@example.com")
      refute has_element?(view, "a", "Connect Salesforce")
      assert has_element?(view, "a", "Connect another Salesforce")
    end

    test "shows Connect button when no Salesforce account connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      assert has_element?(view, "a", "Connect Salesforce")
    end
  end
end
