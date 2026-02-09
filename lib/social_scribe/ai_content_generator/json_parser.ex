defmodule SocialScribe.AIContentGenerator.JsonParser do
  @moduledoc """
  Parses JSON suggestions from AI responses with multiple fallback strategies.
  Handles various formats including code blocks, plain JSON arrays, and nested structures.
  """

  require Logger

  @doc """
  Parses JSON suggestions from an AI response string.

  Tries multiple parsing strategies:
  1. Extract JSON from code blocks (```json ... ```)
  2. Parse as plain JSON
  3. Extract JSON array from text
  4. Return empty list if all strategies fail

  Returns `{:ok, list}` where list contains formatted suggestion maps, or `{:ok, []}` if parsing fails.
  """
  @type suggestion :: %{
          field: String.t(),
          value: String.t(),
          context: String.t() | nil,
          timestamp: String.t() | nil
        }

  @spec parse_suggestions(String.t()) :: {:ok, list(suggestion())}
  def parse_suggestions(response) when is_binary(response) do
    response
    |> extract_from_code_block()
    |> String.trim()
    |> try_parse_json()
    |> case do
      {:ok, suggestions} when is_list(suggestions) ->
        {:ok, format_suggestions(suggestions)}

      {:ok, _} ->
        {:ok, []}

      {:error, _} ->
        try_extract_array(response)
    end
  end

  def parse_suggestions(_), do: {:ok, []}

  # Strategy 1: Extract JSON from code blocks
  defp extract_from_code_block(response) do
    case Regex.run(~r/```json\n?(.*?)```/s, response) do
      [_, json_content] -> json_content
      _ -> response
    end
  end

  # Strategy 2: Try parsing as plain JSON
  defp try_parse_json(cleaned) do
    Jason.decode(cleaned)
  end

  # Strategy 3: Extract JSON array from text and retry parsing
  defp try_extract_array(original_response) do
    case Regex.run(~r/\[.*\]/s, original_response) do
      [json_array] when json_array != original_response ->
        # Avoid infinite recursion by checking if we've already extracted this
        parse_suggestions(json_array)

      _ ->
        Logger.warning("Failed to parse JSON suggestions from AI response")
        {:ok, []}
    end
  end

  # Format parsed suggestions into consistent structure
  defp format_suggestions(suggestions) when is_list(suggestions) do
    suggestions
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn s ->
      %{
        field: Map.get(s, "field"),
        value: Map.get(s, "value"),
        context: Map.get(s, "context"),
        timestamp: Map.get(s, "timestamp")
      }
    end)
    |> Enum.filter(fn s -> s.field != nil and s.value != nil end)
  end

  defp format_suggestions(_), do: []
end
