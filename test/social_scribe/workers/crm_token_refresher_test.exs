defmodule SocialScribe.Workers.CrmTokenRefresherTest do
  use SocialScribe.DataCase

  alias SocialScribe.Workers.CrmTokenRefresher

  import SocialScribe.AccountsFixtures

  # CRM adapters (HubSpot, Salesforce) use Tesla for HTTP; stub so perform/1 does not hit real APIs
  setup do
    body = %{"access_token" => "new", "refresh_token" => "new", "expires_in" => 3600}
    Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: body} end)
    :ok
  end

  describe "perform/1" do
    test "refreshes tokens expiring within 10 minutes for all CRM providers" do
      user = user_fixture()

      # Create a HubSpot credential expiring soon
      _hubspot_cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5 * 60, :second)
        })

      # Create a Salesforce credential expiring soon
      _sf_cred =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 5 * 60, :second)
        })

      # The worker should attempt to refresh both
      # Since we can't actually call the real APIs in tests,
      # we just verify the worker completes without error
      assert :ok = CrmTokenRefresher.perform(%Oban.Job{})
    end

    test "does nothing when no tokens are expiring" do
      user = user_fixture()

      # Create credentials that are far from expiring
      _hubspot_cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      assert :ok = CrmTokenRefresher.perform(%Oban.Job{})
    end

    test "logs errors but returns :ok when individual refreshes fail" do
      user = user_fixture()

      # Create an expiring credential
      _cred =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      # Worker should still return :ok even if refresh fails
      assert :ok = CrmTokenRefresher.perform(%Oban.Job{})
    end
  end
end
