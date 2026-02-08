defmodule SocialScribeWeb.AuthControllerTest do
  use SocialScribeWeb.ConnCase

  alias SocialScribe.Accounts
  alias SocialScribe.Repo

  describe "Auth request" do
    test "GET /auth/google returns redirect or request page", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")
      # Ueberauth may redirect to provider or render; accept either
      assert conn.status in [200, 302]
    end
  end

  describe "Google OAuth callback (new user sign-in)" do
    @describetag :capture_log

    test "creates user and logs in on first Google sign-in", %{conn: conn} do
      auth = google_ueberauth_auth()

      conn =
        conn
        |> assign(:ueberauth_auth, auth)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == ~p"/dashboard"
      user = Accounts.get_user_by_email(auth.info.email)
      assert user != nil
    end
  end

  describe "HubSpot OAuth callback" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "creates hubspot credential on callback", %{conn: conn, user: user} do
      auth = hubspot_ueberauth_auth()

      conn =
        conn
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)
        |> get(~p"/auth/hubspot/callback")

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "HubSpot"
      cred = Accounts.get_user_crm_credential(user.id, "hubspot")
      assert cred != nil
      assert cred.provider == "hubspot"
    end
  end

  describe "Google OAuth callback (add account for logged-in user)" do
    @describetag :capture_log

    setup :register_and_log_in_user

    test "adds Google credential for current user", %{conn: conn, user: user} do
      auth = google_ueberauth_auth()

      conn =
        conn
        |> assign(:ueberauth_auth, auth)
        |> assign(:current_user, user)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Google"
      cred = Repo.get_by(SocialScribe.Accounts.UserCredential, user_id: user.id, provider: "google")
      assert cred != nil
    end
  end

  defp google_ueberauth_auth(overrides \\ %{}) do
    email = overrides[:email] || "user#{System.unique_integer([:positive])}@example.com"
    %Ueberauth.Auth{
      uid: overrides[:uid] || "google_#{System.unique_integer([:positive])}",
      provider: :google,
      credentials: %Ueberauth.Auth.Credentials{
        token: overrides[:token] || "google_token",
        refresh_token: overrides[:refresh_token] || "google_refresh",
        expires_at: overrides[:expires_at] || System.system_time(:second) + 3600
      },
      info: %Ueberauth.Auth.Info{
        email: email,
        name: overrides[:name] || "Google User"
      }
    }
  end

  defp hubspot_ueberauth_auth(overrides \\ %{}) do
    %Ueberauth.Auth{
      uid: overrides[:uid] || "hub_123",
      provider: :hubspot,
      credentials: %Ueberauth.Auth.Credentials{
        token: overrides[:token] || "hubspot_token",
        refresh_token: overrides[:refresh_token] || "hubspot_refresh",
        expires_at: overrides[:expires_at] || System.system_time(:second) + 3600
      },
      info: %Ueberauth.Auth.Info{
        email: overrides[:email] || "user@hubspot.com",
        name: overrides[:name] || "HubSpot User"
      }
    }
  end
end
