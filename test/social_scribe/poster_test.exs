defmodule SocialScribe.PosterTest do
  use SocialScribe.DataCase

  alias SocialScribe.Poster

  import SocialScribe.AccountsFixtures

  describe "post_on_social_media/3" do
    test "returns error for unsupported platform" do
      user = user_fixture()

      assert {:error, "Unsupported platform"} =
               Poster.post_on_social_media(:twitter, "content", user)
    end

    test "LinkedIn: returns error when user has no LinkedIn credential" do
      user = user_fixture()
      # No LinkedIn credential created

      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 201, body: %{"id" => "post-123"}} end)

      assert {:error, "LinkedIn credential not found"} =
               Poster.post_on_social_media(:linkedin, "Hello world", user)
    end

    test "LinkedIn: posts successfully when user has LinkedIn credential" do
      user = user_fixture()

      _cred =
        user_credential_fixture(%{
          user_id: user.id,
          provider: "linkedin",
          token: "linkedin_token",
          uid: "urn:li:person:abc123"
        })

      Tesla.Mock.mock(fn %{method: :post, url: url} ->
        assert url =~ "linkedin.com"
        assert url =~ "ugcPosts"
        %Tesla.Env{status: 201, body: %{"id" => "post-456"}}
      end)

      assert {:ok, %{"id" => "post-456"}} =
               Poster.post_on_social_media(:linkedin, "My post content", user)
    end

    test "LinkedIn: returns error when API fails" do
      user = user_fixture()

      user_credential_fixture(%{
        user_id: user.id,
        provider: "linkedin",
        token: "tk",
        uid: "urn:li:person:xyz"
      })

      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{status: 401, body: %{"message" => "Unauthorized"}}
      end)

      assert {:error, _} = Poster.post_on_social_media(:linkedin, "Content", user)
    end

    test "Facebook: returns error when user has no selected Facebook page credential" do
      user = user_fixture()
      # No Facebook page credential with selected: true

      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 200, body: %{"id" => "post-789"}} end)

      assert {:error, "Facebook page credential not found"} =
               Poster.post_on_social_media(:facebook, "Hello world", user)
    end

    test "Facebook: posts successfully when user has selected Facebook page credential" do
      user = user_fixture()

      _page_cred =
        facebook_page_credential_fixture(%{
          user_id: user.id,
          selected: true,
          facebook_page_id: "page-123",
          page_access_token: "page_token"
        })

      Tesla.Mock.mock(fn %{method: :post, url: url} ->
        assert url =~ "facebook.com"
        assert url =~ "page-123"
        assert url =~ "feed"
        %Tesla.Env{status: 200, body: %{"id" => "page-123_post-1"}}
      end)

      assert {:ok, %{"id" => "page-123_post-1"}} =
               Poster.post_on_social_media(:facebook, "My post content", user)
    end

    test "Facebook: returns error when API fails" do
      user = user_fixture()

      facebook_page_credential_fixture(%{
        user_id: user.id,
        selected: true,
        facebook_page_id: "page-456",
        page_access_token: "token"
      })

      Tesla.Mock.mock(fn %{method: :post} ->
        %Tesla.Env{status: 403, body: %{"error" => %{"message" => "Forbidden"}}}
      end)

      assert {:error, _} = Poster.post_on_social_media(:facebook, "Content", user)
    end
  end
end
