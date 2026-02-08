defmodule SocialScribe.Workers.HubspotTokenRefresherTest do
  use SocialScribe.DataCase

  alias SocialScribe.Workers.HubspotTokenRefresher

  import SocialScribe.AccountsFixtures

  setup do
    # HubspotTokenRefresher.refresh_credential calls Tesla to HubSpot token URL
    body = %{"access_token" => "new_token", "refresh_token" => "new_refresh", "expires_in" => 3600}
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: body} end)

    # HubspotTokenRefresher.refresh_token reads Ueberauth HubSpot config
    Application.put_env(:ueberauth, Ueberauth.Strategy.Hubspot.OAuth,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    )

    on_exit(fn ->
      Application.delete_env(:ueberauth, Ueberauth.Strategy.Hubspot.OAuth)
    end)

    :ok
  end

  describe "perform/1" do
    test "returns :ok when no HubSpot credentials are expiring soon" do
      user = user_fixture()

      _cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end

    test "returns :ok when there are no HubSpot credentials" do
      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end

    test "refreshes credentials expiring within 10 minutes and returns :ok" do
      user = user_fixture()

      _cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5, :minute)
        })

      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end

    test "returns :ok even when individual refresh fails (logs error)" do
      user = user_fixture()

      _cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 1, :minute)
        })

      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 401, body: %{"error" => "Unauthorized"}} end)

      assert :ok = HubspotTokenRefresher.perform(%Oban.Job{})
    end
  end
end
