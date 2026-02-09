defmodule SocialScribeWeb.Helpers.Markdown do
  @moduledoc """
  Helper functions for rendering markdown content.
  """

  @doc """
  Renders markdown text to HTML.

  Returns safe HTML that can be used with `raw/1`.
  Handles nil and empty strings gracefully.
  """
  def render_markdown(nil), do: Phoenix.HTML.raw("")
  def render_markdown(""), do: Phoenix.HTML.raw("")

  def render_markdown(text) when is_binary(text) do
    case Earmark.as_html(text) do
      {:ok, html, _} -> Phoenix.HTML.raw(html)
      {:error, _html, _errors} -> Phoenix.HTML.html_escape(text)
    end
  end

  def render_markdown(_), do: Phoenix.HTML.raw("")
end
