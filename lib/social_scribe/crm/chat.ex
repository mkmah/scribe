defmodule SocialScribe.Crm.Chat do
  @moduledoc """
  Context module for the "Ask Anything" CRM chat feature.

  Handles:
  - Conversation CRUD
  - Message persistence
  - Mention parsing (@Name)
  - Contact lookup via CRM APIs
  - AI question answering
  """

  alias SocialScribe.Repo
  alias SocialScribe.Crm.ChatConversation
  alias SocialScribe.Crm.ChatMessage
  alias SocialScribe.Crm.Registry
  alias SocialScribe.Accounts

  import Ecto.Query

  @mention_regex ~r/@([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*)/

  # --- Mention Parsing ---

  @doc """
  Extracts @Name mentions from text.
  Returns a list of name strings (without the @ prefix).
  """
  @spec parse_mentions(String.t()) :: list(String.t())
  def parse_mentions(text) when is_binary(text) do
    @mention_regex
    |> Regex.scan(text)
    |> Enum.map(fn [_full, name] -> name end)
  end

  # --- Conversation CRUD ---

  @doc """
  Creates a new conversation.
  """
  @spec create_conversation(map()) :: {:ok, ChatConversation.t()} | {:error, Ecto.Changeset.t()}
  def create_conversation(attrs) do
    %ChatConversation{}
    |> ChatConversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists conversations for a user, ordered by most recent first.
  """
  @spec list_conversations(integer()) :: list(ChatConversation.t())
  def list_conversations(user_id) do
    from(c in ChatConversation,
      where: c.user_id == ^user_id,
      order_by: [desc: c.inserted_at, desc: c.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a conversation by ID.
  """
  @spec get_conversation!(integer()) :: ChatConversation.t()
  def get_conversation!(id) do
    Repo.get!(ChatConversation, id)
  end

  # --- Message CRUD ---

  @doc """
  Adds a message to a conversation.
  """
  @spec add_message(integer(), map()) :: {:ok, ChatMessage.t()} | {:error, Ecto.Changeset.t()}
  def add_message(conversation_id, attrs) do
    attrs = Map.put(attrs, :conversation_id, conversation_id)

    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all messages for a conversation, ordered chronologically.
  """
  @spec get_conversation_messages(integer()) :: list(ChatMessage.t())
  def get_conversation_messages(conversation_id) do
    from(m in ChatMessage,
      where: m.conversation_id == ^conversation_id,
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  # --- Ask Flow ---

  @doc """
  Main "ask" flow: parses mentions, fetches contacts, calls AI, persists messages.
  Returns `{:ok, %{user_message: msg, assistant_message: msg}}`.
  """
  @spec ask(integer(), String.t(), integer()) ::
          {:ok, %{user_message: ChatMessage.t(), assistant_message: ChatMessage.t()}}
          | {:error, any()}
  def ask(conversation_id, question, user_id) do
    with {:ok, user_message} <-
           add_message(conversation_id, %{role: "user", content: question}) do
      # 2. Parse mentions and fetch contact data
      mentions = parse_mentions(question)
      contact_data = fetch_mentioned_contacts(mentions, user_id)

      # 3. Build context for AI
      context = %{
        "question" => question,
        "contacts" => format_contacts_for_ai(contact_data),
        "mentions" => mentions
      }

      # 4. Call AI
      ai_response =
        case ai_impl().answer_crm_question(question, context) do
          {:ok, answer} -> answer
          {:error, _reason} -> "I'm sorry, I couldn't process your question. Please try again."
        end

      # 5. Persist the assistant message
      metadata = %{
        "sources" => Enum.map(contact_data, fn {provider, _contacts} -> provider end),
        "contacts" => mentions
      }

      case add_message(conversation_id, %{
             role: "assistant",
             content: ai_response,
             metadata: metadata
           }) do
        {:ok, assistant_message} ->
          {:ok, %{user_message: user_message, assistant_message: assistant_message}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # --- Private Helpers ---

  defp fetch_mentioned_contacts([], _user_id), do: []

  defp fetch_mentioned_contacts(mentions, user_id) do
    Registry.crm_providers()
    |> Enum.flat_map(fn provider ->
      case Accounts.get_user_crm_credential(user_id, provider) do
        nil ->
          []

        credential ->
          adapter = crm_impl(provider)

          Enum.flat_map(mentions, fn name ->
            case adapter.search_contacts(credential, name) do
              {:ok, contacts} -> [{provider, contacts}]
              {:error, _} -> []
            end
          end)
      end
    end)
  end

  defp format_contacts_for_ai(contact_data) do
    Enum.flat_map(contact_data, fn {provider, contacts} ->
      Enum.map(contacts, fn contact ->
        %{
          "provider" => provider,
          "name" => contact.display_name,
          "email" => contact.email,
          "company" => contact.company,
          "job_title" => contact.job_title,
          "phone" => contact.phone
        }
      end)
    end)
  end

  defp crm_impl(provider) do
    case Application.get_env(:social_scribe, :crm_api) do
      nil -> Registry.adapter_for!(provider)
      mock -> mock
    end
  end

  defp ai_impl do
    Application.get_env(
      :social_scribe,
      :ai_content_generator_api,
      SocialScribe.AIContentGenerator
    )
  end
end
