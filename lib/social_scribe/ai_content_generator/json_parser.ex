defmodule SocialScribe.AIContentGenerator.JsonParser do
  @moduledoc """
  Parses JSON suggestions from AI responses with multiple fallback strategies.
  Handles various formats including code blocks, plain JSON arrays, and nested structures.
  """

  require Logger

  @doc """
  Parses JSON suggestions from an AI response string.

  Tries multiple parsing strategies:
  1. Extract JSON from code blocks (```json ... ``` or ``` ... ```)
  2. Parse as plain JSON
  3. Extract JSON array from text
  4. Return error if all strategies fail

  Returns `{:ok, list}` where list contains formatted suggestion maps, or `{:error, reason}` if parsing fails.
  """
  @type suggestion :: %{
          field: String.t(),
          value: String.t(),
          context: String.t() | nil,
          timestamp: String.t() | nil
        }

  @spec parse_suggestions(String.t()) :: {:ok, list(suggestion())} | {:error, any()}
  def parse_suggestions(response) when is_binary(response) do
    Logger.debug(
      "JsonParser: Starting to parse suggestions. Response length: #{String.length(response)}"
    )

    Logger.debug("JsonParser: Raw response (first 500 chars): #{String.slice(response, 0, 500)}")

    result =
      response
      |> extract_from_code_block()
      |> String.trim()
      |> try_parse_json()
      |> case do
        {:ok, suggestions} when is_list(suggestions) ->
          formatted = format_suggestions(suggestions)
          Logger.debug("JsonParser: Successfully parsed #{length(formatted)} suggestions")
          {:ok, formatted}

        {:ok, parsed} ->
          # Valid JSON but not a list - means no suggestions found (empty result)
          Logger.debug("JsonParser: Parsed JSON but result is not a list: #{inspect(parsed)}. Returning empty list.")
          {:ok, []}

        {:error, jason_error} ->
          Logger.debug("JsonParser: Plain JSON parsing failed: #{inspect(jason_error)}")
          try_extract_array(response)
      end

    case result do
      {:ok, _suggestions} ->
        result

      {:error, reason} ->
        Logger.error("JsonParser: All parsing strategies failed. Error: #{inspect(reason)}")
        Logger.error("JsonParser: Full response: #{response}")
        result
    end
  end

  def parse_suggestions(non_binary) do
    Logger.error("JsonParser: Received non-binary input: #{inspect(non_binary)}")
    {:error, {:invalid_input, "Expected binary string, got: #{inspect(non_binary)}"}}
  end

  # Strategy 1: Extract JSON from code blocks
  # Handles both ```json ... ``` and ``` ... ``` formats
  defp extract_from_code_block(response) do
    # Try ```json ... ``` first
    case Regex.run(~r/```json\n?(.*?)```/s, response) do
      [_, json_content] ->
        Logger.debug("JsonParser: Extracted JSON from ```json code block")
        json_content

      _ ->
        # Try generic ``` ... ``` code block
        case Regex.run(~r/```\n?(.*?)```/s, response) do
          [_, json_content] ->
            Logger.debug("JsonParser: Extracted JSON from generic code block")
            json_content

          _ ->
            Logger.debug("JsonParser: No code blocks found, using raw response")
            response
        end
    end
  end

  # Strategy 2: Try parsing as plain JSON
  defp try_parse_json(cleaned) do
    Jason.decode(cleaned)
  end

  # Strategy 3: Extract JSON array from text and retry parsing
  defp try_extract_array(original_response) do
    Logger.debug("JsonParser: Attempting to extract JSON array from text")

    # Find balanced brackets by counting opening and closing brackets
    json_array = extract_balanced_array(original_response)

    if json_array && json_array != original_response do
      Logger.debug(
        "JsonParser: Extracted JSON array (#{String.length(json_array)} chars), attempting parse"
      )

      # Parse directly to avoid recursion
      case Jason.decode(json_array) do
        {:ok, suggestions} when is_list(suggestions) ->
          formatted = format_suggestions(suggestions)

          Logger.debug(
            "JsonParser: Successfully parsed #{length(formatted)} suggestions from extracted array"
          )

          {:ok, formatted}

        {:ok, _} ->
          Logger.warning("JsonParser: Extracted array but parsed result is not a list")
          log_parsing_failure(original_response)

        {:error, jason_error} ->
          Logger.warning("JsonParser: Failed to parse extracted array: #{inspect(jason_error)}")
          log_parsing_failure(original_response)
      end
    else
      log_parsing_failure(original_response)
    end
  end

  # Extract a balanced JSON array from text by finding matching brackets
  defp extract_balanced_array(text) do
    case String.split(text, "[", parts: 2) do
      [_before, rest] ->
        # Find the matching closing bracket
        case find_balanced_content(rest, 0, "") do
          {array_content, _} when is_binary(array_content) ->
            "[" <> array_content <> "]"

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Helper to find balanced bracket content
  # Returns {content_between_brackets, remaining_text} or {nil, remaining_text} if unbalanced
  defp find_balanced_content(remaining, depth, _acc) when depth < 0, do: {nil, remaining}

  defp find_balanced_content("", 0, acc), do: {acc, ""}
  defp find_balanced_content("", _, _), do: {nil, ""}

  defp find_balanced_content(<<char::utf8, rest::binary>>, depth, acc) do
    case char do
      ?[ ->
        find_balanced_content(rest, depth + 1, acc <> "[")

      ?] ->
        if depth == 0 do
          {acc, rest}
        else
          find_balanced_content(rest, depth - 1, acc <> "]")
        end

      _ ->
        find_balanced_content(rest, depth, acc <> <<char::utf8>>)
    end
  end

  defp log_parsing_failure(response) do
    Logger.error("JsonParser: Failed to extract JSON array from response")
    Logger.error("JsonParser: Response preview: #{String.slice(response, 0, 1000)}")
    {:error, {:parsing_error, "Could not extract valid JSON array from AI response"}}
  end

  # Format parsed suggestions into consistent structure
  defp format_suggestions(suggestions) when is_list(suggestions) do
    formatted =
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

    if length(formatted) != length(suggestions) do
      filtered_count = length(suggestions) - length(formatted)

      Logger.debug(
        "JsonParser: Filtered out #{filtered_count} invalid suggestions (missing field or value)"
      )
    end

    formatted
  end

  defp format_suggestions(_), do: []
end
