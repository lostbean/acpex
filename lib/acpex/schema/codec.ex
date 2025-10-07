defmodule ACPex.Schema.Codec do
  @moduledoc """
  Encoding and decoding utilities for ACP schemas.

  This module provides functions to convert between Ecto schemas and JSON,
  automatically handling the camelCase ↔ snake_case conversion via the
  `:source` field option defined in each schema.

  ## Features

  - **Encoding**: Converts Ecto schemas to JSON strings with camelCase keys
  - **Decoding**: Converts JSON strings to Ecto schemas with snake_case fields
  - Automatic case conversion via `:source` field mappings
  - Nil values are automatically omitted from encoded output
  - Proper error handling and validation

  ## Examples

      # Encoding
      request = %ACPex.Schema.Connection.InitializeRequest{
        protocol_version: 1,
        capabilities: %{}
      }
      ACPex.Schema.Codec.encode!(request)
      #=> ~s({"protocolVersion":1,"capabilities":{}})

      # Decoding
      json = ~s({"protocolVersion":1,"capabilities":{}})
      ACPex.Schema.Codec.decode!(json, ACPex.Schema.Connection.InitializeRequest)
      #=> %ACPex.Schema.Connection.InitializeRequest{protocol_version: 1, capabilities: %{}}

  ## Design Philosophy

  This module eliminates the need for manual case conversion by leveraging
  Ecto's built-in support for field name mapping via the `:source` option.
  Each schema defines its own mappings, making them self-documenting and
  serving as the single source of truth for the protocol specification.
  """

  @doc """
  Encodes an Ecto schema struct to a JSON string.

  Uses `Ecto.embedded_dump/2` to convert the struct to a map with camelCase
  keys (respecting `:source` field mappings), then encodes to JSON.

  ## Parameters

    * `struct` - An Ecto schema struct to encode

  ## Returns

  A JSON string representation of the struct with camelCase keys.

  ## Examples

      iex> request = %InitializeRequest{protocol_version: 1, capabilities: %{}}
      iex> ACPex.Schema.Codec.encode!(request)
      ~s({"protocolVersion":1,"capabilities":{}})

  """
  @spec encode!(struct()) :: String.t()
  def encode!(struct) when is_struct(struct) do
    struct
    |> Ecto.embedded_dump(:json)
    |> atomize_keys_to_strings()
    |> remove_nil_values()
    |> Jason.encode!()
  end

  @doc """
  Encodes an Ecto schema struct to a map with camelCase keys.

  Similar to `encode!/1` but returns a map instead of a JSON string.
  Useful for composing nested structures.

  ## Parameters

    * `struct` - An Ecto schema struct to encode

  ## Returns

  A map with camelCase keys.

  ## Examples

      iex> request = %InitializeRequest{protocol_version: 1, capabilities: %{}}
      iex> ACPex.Schema.Codec.encode_to_map!(request)
      %{"protocolVersion" => 1, "capabilities" => %{}}

  """
  @spec encode_to_map!(struct()) :: map()
  def encode_to_map!(struct) when is_struct(struct) do
    struct
    |> Ecto.embedded_dump(:json)
    |> atomize_keys_to_strings()
    |> remove_nil_values()
  end

  @doc """
  Decodes a JSON string into an Ecto schema struct.

  Uses `Jason.decode/1` to parse the JSON, then `Ecto.embedded_load/3` to
  convert the camelCase keys to snake_case fields according to the schema's
  `:source` field mappings.

  ## Parameters

    * `json` - JSON string to decode
    * `schema_module` - The Ecto schema module to decode into

  ## Returns

  `{:ok, struct}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> json = ~s({"protocolVersion":1,"capabilities":{}})
      iex> ACPex.Schema.Codec.decode(json, InitializeRequest)
      {:ok, %InitializeRequest{protocol_version: 1, capabilities: %{}}}

  """
  @spec decode(String.t(), module()) :: {:ok, struct()} | {:error, term()}
  def decode(json, schema_module) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json) do
      decode_from_map(data, schema_module)
    end
  end

  @doc """
  Decodes a JSON string into an Ecto schema struct.

  Same as `decode/2` but raises on error.

  ## Parameters

    * `json` - JSON string to decode
    * `schema_module` - The Ecto schema module to decode into

  ## Returns

  An Ecto schema struct.

  ## Examples

      iex> json = ~s({"protocolVersion":1,"capabilities":{}})
      iex> ACPex.Schema.Codec.decode!(json, InitializeRequest)
      %InitializeRequest{protocol_version: 1, capabilities: %{}}

  """
  @spec decode!(String.t(), module()) :: struct()
  def decode!(json, schema_module) when is_binary(json) do
    case decode(json, schema_module) do
      {:ok, struct} ->
        struct

      {:error, reason} ->
        raise ArgumentError,
              "Failed to decode JSON into #{inspect(schema_module)}: #{inspect(reason)}"
    end
  end

  @doc """
  Decodes a map with camelCase keys into an Ecto schema struct.

  Uses `Ecto.embedded_load/3` to convert the map to a struct, respecting
  the schema's `:source` field mappings.

  ## Parameters

    * `data` - Map with camelCase string keys
    * `schema_module` - The Ecto schema module to decode into

  ## Returns

  `{:ok, struct}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> data = %{"protocolVersion" => 1, "capabilities" => %{}}
      iex> ACPex.Schema.Codec.decode_from_map(data, InitializeRequest)
      {:ok, %InitializeRequest{protocol_version: 1, capabilities: %{}}}

  """
  @spec decode_from_map(map(), module()) :: {:ok, struct()} | {:error, term()}
  def decode_from_map(data, schema_module) when is_map(data) do
    try do
      struct = Ecto.embedded_load(schema_module, data, :json)
      {:ok, struct}
    rescue
      e ->
        {:error, e}
    end
  end

  @doc """
  Decodes a map with camelCase keys into an Ecto schema struct.

  Same as `decode_from_map/2` but raises on error.

  ## Parameters

    * `data` - Map with camelCase string keys
    * `schema_module` - The Ecto schema module to decode into

  ## Returns

  An Ecto schema struct.

  ## Examples

      iex> data = %{"protocolVersion" => 1, "capabilities" => %{}}
      iex> ACPex.Schema.Codec.decode_from_map!(data, InitializeRequest)
      %InitializeRequest{protocol_version: 1, capabilities: %{}}

  """
  @spec decode_from_map!(map(), module()) :: struct()
  def decode_from_map!(data, schema_module) when is_map(data) do
    case decode_from_map(data, schema_module) do
      {:ok, struct} ->
        struct

      {:error, reason} ->
        raise ArgumentError,
              "Failed to decode map into #{inspect(schema_module)}: #{inspect(reason)}"
    end
  end

  # Private Functions

  # Converts atom keys to string keys recursively
  # This is needed because Ecto.embedded_dump returns atom keys,
  # but JSON requires string keys
  defp atomize_keys_to_strings(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) ->
        {Atom.to_string(key), atomize_keys_to_strings(value)}

      {key, value} ->
        {key, atomize_keys_to_strings(value)}
    end)
    |> Enum.into(%{})
  end

  defp atomize_keys_to_strings(list) when is_list(list) do
    Enum.map(list, &atomize_keys_to_strings/1)
  end

  defp atomize_keys_to_strings(value), do: value

  # Recursively removes nil values from maps
  # This ensures protocol compliance by omitting optional fields that are nil
  defp remove_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} -> {key, remove_nil_values(value)} end)
    |> Enum.into(%{})
  end

  defp remove_nil_values(list) when is_list(list) do
    Enum.map(list, &remove_nil_values/1)
  end

  defp remove_nil_values(value), do: value
end
