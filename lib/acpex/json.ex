defmodule ACPex.Json do
  @moduledoc """
  JSON encoding and decoding utilities for the Agent Client Protocol.

  This module provides symmetric JSON serialization, automatically converting
  between Elixir's `snake_case` atom keys and JSON's `camelCase` string keys.
  This ensures protocol compliance while maintaining idiomatic Elixir code.

  ## Features

  - **Encoding**: Converts `snake_case` struct field names to `camelCase` JSON keys
  - **Decoding**: Converts `camelCase` JSON keys to `snake_case` atom keys
  - Automatically omits `nil` values from encoded output
  - Used by all `ACPex.Schema` structs

  ## Examples

      defmodule MyMessage do
        use ACPex.Json
        defstruct [:protocol_version, :client_info]
      end

      # Encoding
      msg = %MyMessage{protocol_version: "1.0", client_info: nil}
      Jason.encode!(msg)
      # => "{\"protocolVersion\":\"1.0\"}"

      # Decoding
      json = ~s({"protocolVersion":"1.0","clientInfo":{"name":"test"}})
      ACPex.Json.decode(json, MyMessage)
      # => {:ok, %MyMessage{protocol_version: "1.0", client_info: %{"name" => "test"}}}

  ## Protocol Compliance

  The ACP specification uses `camelCase` for all JSON keys, following JavaScript
  conventions. This module ensures automatic conversion so Elixir developers can
  use conventional `snake_case` atom keys in their code.

  """

  @doc """
  Decodes a JSON string into a struct, converting camelCase keys to snake_case.

  ## Parameters

    * `json` - JSON string to decode
    * `struct_module` - The struct module to decode into (e.g., `ACPex.Schema.InitializeRequest`)

  ## Returns

  `{:ok, struct}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> json = ~s({"protocolVersion":"1.0"})
      iex> ACPex.Json.decode(json, ACPex.Schema.InitializeRequest)
      {:ok, %ACPex.Schema.InitializeRequest{protocol_version: "1.0"}}

  """
  @spec decode(String.t(), module()) :: {:ok, struct()} | {:error, term()}
  def decode(json, struct_module) do
    with {:ok, data} <- Jason.decode(json) do
      struct = decode_into_struct(data, struct_module)
      {:ok, struct}
    end
  end

  @doc """
  Decodes a JSON string into a struct, converting camelCase keys to snake_case.

  Same as `decode/2` but raises on error.

  ## Examples

      iex> json = ~s({"protocolVersion":"1.0"})
      iex> ACPex.Json.decode!(json, ACPex.Schema.InitializeRequest)
      %ACPex.Schema.InitializeRequest{protocol_version: "1.0"}

  """
  @spec decode!(String.t(), module()) :: struct()
  def decode!(json, struct_module) do
    case decode(json, struct_module) do
      {:ok, struct} -> struct
      {:error, reason} -> raise "Failed to decode JSON: #{inspect(reason)}"
    end
  end

  @doc """
  Converts a map with camelCase string keys to a struct with snake_case atom keys.

  ## Parameters

    * `data` - Map with camelCase string keys
    * `struct_module` - The struct module to convert into

  ## Examples

      iex> data = %{"protocolVersion" => "1.0", "clientInfo" => nil}
      iex> ACPex.Json.decode_into_struct(data, MyStruct)
      %MyStruct{protocol_version: "1.0", client_info: nil}

  """
  @spec decode_into_struct(map(), module()) :: struct()
  def decode_into_struct(data, struct_module) when is_map(data) do
    snake_case_data =
      data
      |> Enum.map(fn {key, value} ->
        snake_key = key |> Inflex.underscore() |> String.to_atom()
        {snake_key, value}
      end)
      |> Enum.into(%{})

    struct(struct_module, snake_case_data)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Jason.Encoder

      @doc """
      Encodes the struct to JSON, converting snake_case keys to camelCase.

      Nil values are automatically omitted from the output.
      """
      def encode(struct, opts) do
        struct
        |> Map.from_struct()
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          # Remove nil values from the encoded map
          if value != nil do
            camel_key = Macro.to_string(key) |> Inflex.camelize(:lower)
            Map.put(acc, camel_key, value)
          else
            acc
          end
        end)
        |> Jason.Encode.map(opts)
      end
    end
  end
end
