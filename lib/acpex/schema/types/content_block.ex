defmodule ACPex.Schema.Types.ContentBlock do
  @moduledoc """
  Content block union type.

  A ContentBlock can be one of several variants, discriminated by the `type` field:

  - `"text"` - Plain text content (ACPex.Schema.Types.ContentBlock.Text)
  - `"image"` - Image data (ACPex.Schema.Types.ContentBlock.Image)
  - `"audio"` - Audio data (ACPex.Schema.Types.ContentBlock.Audio)
  - `"resource_link"` - External resource reference (ACPex.Schema.Types.ContentBlock.ResourceLink)
  - `"resource"` - Embedded resource contents (ACPex.Schema.Types.ContentBlock.Resource)

  ## Usage

  You can use any of the variant structs directly:

      # Text content
      %ACPex.Schema.Types.ContentBlock.Text{
        text: "Hello, world!"
      }

      # Image content
      %ACPex.Schema.Types.ContentBlock.Image{
        data: "base64-encoded-data...",
        mime_type: "image/png"
      }

  Or use maps (which will be validated at runtime):

      %{
        "type" => "text",
        "text" => "Hello, world!"
      }

  ## Decoding from JSON

  Use the `decode/1` function to decode JSON into the appropriate variant struct:

      json = ~s({"type":"text","text":"Hello"})
      {:ok, %ACPex.Schema.Types.ContentBlock.Text{}} = ContentBlock.decode(json)

  ## Encoding to JSON

  All variant structs implement Jason.Encoder:

      text = %ACPex.Schema.Types.ContentBlock.Text{text: "Hello"}
      Jason.encode!(text)
      # => {"type":"text","text":"Hello"}

  """

  alias ACPex.Schema.Types.ContentBlock.{Text, Image, Audio, ResourceLink, Resource}

  @type variant :: Text.t() | Image.t() | Audio.t() | ResourceLink.t() | Resource.t()
  @type t :: variant()

  @doc """
  Decodes a JSON string or map into the appropriate ContentBlock variant struct.

  The `type` field is used as a discriminator to determine which variant to decode to.

  ## Examples

      iex> ContentBlock.decode(~s({"type":"text","text":"Hello"}))
      {:ok, %ContentBlock.Text{type: "text", text: "Hello"}}

      iex> ContentBlock.decode(%{"type" => "image", "data" => "...", "mimeType" => "image/png"})
      {:ok, %ContentBlock.Image{type: "image", data: "...", mime_type: "image/png"}}

      iex> ContentBlock.decode(%{"type" => "unknown"})
      {:error, "Unknown content block type: unknown"}

  """
  @spec decode(String.t() | map()) :: {:ok, variant()} | {:error, String.t()}
  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> decode(map)
      {:error, reason} -> {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  def decode(%{"type" => "text"} = map), do: decode_variant(map, Text)
  def decode(%{"type" => "image"} = map), do: decode_variant(map, Image)
  def decode(%{"type" => "audio"} = map), do: decode_variant(map, Audio)
  def decode(%{"type" => "resource_link"} = map), do: decode_variant(map, ResourceLink)
  def decode(%{"type" => "resource"} = map), do: decode_variant(map, Resource)
  def decode(%{type: type} = map) when is_binary(type), do: decode(stringify_keys(map))
  def decode(%{"type" => type}), do: {:error, "Unknown content block type: #{type}"}
  def decode(_), do: {:error, "Missing type field"}

  @doc """
  Same as `decode/1` but raises on error.
  """
  @spec decode!(String.t() | map()) :: variant()
  def decode!(json) do
    case decode(json) do
      {:ok, struct} -> struct
      {:error, reason} -> raise ArgumentError, "ContentBlock decode error: #{reason}"
    end
  end

  # Private helpers

  defp decode_variant(map, module) do
    case ACPex.Schema.Codec.decode_from_map(map, module) do
      {:ok, struct} -> {:ok, struct}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
