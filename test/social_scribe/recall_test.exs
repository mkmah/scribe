defmodule SocialScribe.RecallTest do
  use ExUnit.Case, async: false

  alias SocialScribe.Recall

  @join_at ~U[2025-01-15 14:00:00Z]

  describe "create_bot/2" do
    test "returns ok with body on 201" do
      Tesla.Mock.mock(fn
        %{method: :post} -> %Tesla.Env{status: 201, body: %{id: "bot-123", status: "pending"}}
      end)

      assert {:ok, %Tesla.Env{status: 201, body: %{id: "bot-123"}}} =
               Recall.create_bot("https://meet.example.com/abc", @join_at)
    end
  end

  describe "get_bot/1" do
    test "returns bot on 200" do
      Tesla.Mock.mock(fn
        %{method: :get} -> %Tesla.Env{status: 200, body: %{id: "bot-456", status: "in_call"}}
      end)

      assert {:ok, %Tesla.Env{status: 200, body: %{id: "bot-456"}}} =
               Recall.get_bot("bot-456")
    end
  end

  describe "update_bot/3" do
    test "returns ok on 200" do
      Tesla.Mock.mock(fn
        %{method: :patch} -> %Tesla.Env{status: 200, body: %{id: "bot-789"}}
      end)

      assert {:ok, %Tesla.Env{status: 200}} =
               Recall.update_bot("bot-789", "https://meet.example.com/new", @join_at)
    end
  end

  describe "delete_bot/1" do
    test "returns ok on 204" do
      Tesla.Mock.mock(fn
        %{method: :delete} -> %Tesla.Env{status: 204, body: nil}
      end)

      assert {:ok, %Tesla.Env{status: 204}} = Recall.delete_bot("bot-del")
    end
  end
end
