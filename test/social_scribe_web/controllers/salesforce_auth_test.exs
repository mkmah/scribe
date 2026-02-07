defmodule SocialScribeWeb.SalesforceAuthTest do
  use SocialScribeWeb.ConnCase

  import SocialScribe.AccountsFixtures

  alias SocialScribe.Accounts

  describe "Salesforce OAuth callback" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "creates salesforce credential on successful auth", %{conn: conn, user: user} do
      auth = salesforce_ueberauth_auth()

      conn =
        conn
        |> assign(:ueberauth_auth, auth)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce"

      cred = Accounts.get_user_crm_credential(user.id, "salesforce")
      assert cred != nil
      assert cred.provider == "salesforce"
      assert cred.token == "sf_access_token_123"
      assert cred.refresh_token == "sf_refresh_token_123"
    end

    test "stores instance_url from token response", %{conn: conn, user: user} do
      auth = salesforce_ueberauth_auth()

      conn
      |> assign(:ueberauth_auth, auth)
      |> get(~p"/auth/salesforce/callback")

      cred = Accounts.get_user_crm_credential(user.id, "salesforce")
      assert cred != nil
      assert cred.instance_url == "https://myorg.my.salesforce.com"
    end

    test "redirects to settings with success flash", %{conn: conn} do
      auth = salesforce_ueberauth_auth()

      conn =
        conn
        |> assign(:ueberauth_auth, auth)
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Salesforce"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully"
    end

    test "handles auth failure gracefully", %{conn: conn} do
      conn =
        conn
        |> assign(:ueberauth_failure, %Ueberauth.Failure{
          provider: :salesforce,
          errors: [%Ueberauth.Failure.Error{message: "access denied"}]
        })
        |> get(~p"/auth/salesforce/callback")

      assert redirected_to(conn) =~ ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Could not connect Salesforce"
    end

    test "updates existing credential on re-auth", %{conn: conn, user: user} do
      # Create an existing credential
      _existing = salesforce_credential_fixture(%{user_id: user.id, uid: "sf_org_001"})

      auth = salesforce_ueberauth_auth(%{uid: "sf_org_001", token: "new_access_token"})

      conn
      |> assign(:ueberauth_auth, auth)
      |> get(~p"/auth/salesforce/callback")

      # Should still only have one credential
      cred = Accounts.get_user_crm_credential(user.id, "salesforce")
      assert cred.token == "new_access_token"
    end
  end

  defp salesforce_ueberauth_auth(overrides \\ %{}) do
    %Ueberauth.Auth{
      uid: overrides[:uid] || "sf_org_001",
      provider: :salesforce,
      credentials: %Ueberauth.Auth.Credentials{
        token: overrides[:token] || "sf_access_token_123",
        refresh_token: overrides[:refresh_token] || "sf_refresh_token_123",
        expires_at: overrides[:expires_at] || System.system_time(:second) + 7200,
        other: %{instance_url: overrides[:instance_url] || "https://myorg.my.salesforce.com"}
      },
      info: %Ueberauth.Auth.Info{
        email: overrides[:email] || "user@salesforce.com",
        name: overrides[:name] || "Salesforce User"
      }
    }
  end
end
