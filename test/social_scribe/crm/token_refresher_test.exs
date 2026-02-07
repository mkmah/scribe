defmodule SocialScribe.Crm.TokenRefresherTest do
  use SocialScribe.DataCase

  alias SocialScribe.Crm.TokenRefresher

  import SocialScribe.AccountsFixtures

  describe "ensure_valid_token/2" do
    test "returns credential unchanged when token expires in more than 5 minutes" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      adapter = SocialScribe.Crm.Adapters.Hubspot

      assert {:ok, result} = TokenRefresher.ensure_valid_token(credential, adapter)
      assert result.id == credential.id
      assert result.token == credential.token
    end

    test "calls adapter.refresh_token when token expires within 5 minutes" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      # We use CrmApiMock here to test the refresh_token delegation
      SocialScribe.CrmApiMock
      |> Mox.expect(:refresh_token, fn cred ->
        assert cred.id == credential.id
        {:ok, %{cred | token: "refreshed_token"}}
      end)

      assert {:ok, result} =
               TokenRefresher.ensure_valid_token(credential, SocialScribe.CrmApiMock)

      assert result.token == "refreshed_token"
    end

    test "calls adapter.refresh_token when token is already expired" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })

      SocialScribe.CrmApiMock
      |> Mox.expect(:refresh_token, fn cred ->
        assert cred.id == credential.id
        {:ok, %{cred | token: "refreshed_token"}}
      end)

      assert {:ok, result} =
               TokenRefresher.ensure_valid_token(credential, SocialScribe.CrmApiMock)

      assert result.token == "refreshed_token"
    end

    test "returns error when refresh fails" do
      user = user_fixture()

      credential =
        hubspot_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })

      SocialScribe.CrmApiMock
      |> Mox.expect(:refresh_token, fn _cred ->
        {:error, {:token_refresh_failed, "invalid grant"}}
      end)

      assert {:error, _} = TokenRefresher.ensure_valid_token(credential, SocialScribe.CrmApiMock)
    end
  end
end
