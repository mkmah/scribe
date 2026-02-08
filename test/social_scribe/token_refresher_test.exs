defmodule SocialScribe.TokenRefresherTest do
  use ExUnit.Case, async: false

  alias SocialScribe.TokenRefresher

  setup do
    Application.put_env(:ueberauth, Ueberauth.Strategy.Google.OAuth,
      client_id: "test-client",
      client_secret: "test-secret"
    )

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://oauth2.googleapis.com/token"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "access_token" => "new-token",
            "expires_in" => 3600,
            "refresh_token" => "refresh"
          }
        }
    end)

    on_exit(fn ->
      Application.delete_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)
    end)

    :ok
  end

  describe "refresh_token/1" do
    test "returns ok with body on 200" do
      assert {:ok, body} = TokenRefresher.refresh_token("refresh-token")
      assert body["access_token"] == "new-token"
      assert body["expires_in"] == 3600
    end
  end
end
