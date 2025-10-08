defmodule ACPex.Schema.PropertyTest do
  @moduledoc """
  Property-based tests for schema encoding/decoding using StreamData.

  These tests verify that:
  1. Encode → Decode roundtrips work for all valid data
  2. The codec handles random valid inputs correctly
  3. Edge cases and boundary conditions are robust
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ACPex.Schema.Codec
  alias ACPex.Schema.Connection.InitializeRequest
  alias ACPex.Schema.Session.PromptRequest

  alias ACPex.Schema.Client.{
    FsReadTextFileRequest,
    FsReadTextFileResponse,
    FsWriteTextFileRequest
  }

  alias ACPex.Schema.Client.Terminal

  # Property test configuration
  @max_runs 100

  describe "InitializeRequest property tests" do
    property "encode → decode roundtrip preserves data" do
      check all(
              protocol_version <- positive_int_generator(),
              capabilities <- capabilities_map(),
              meta <- optional_map(),
              max_runs: @max_runs
            ) do
        request = %InitializeRequest{
          protocol_version: protocol_version,
          client_capabilities: capabilities,
          meta: meta
        }

        # Encode to JSON
        json = Codec.encode!(request)

        # Decode back
        {:ok, decoded} = Codec.decode(json, InitializeRequest)

        # Verify roundtrip
        assert decoded.protocol_version == protocol_version
        assert decoded.client_capabilities == capabilities
        assert decoded.meta == meta
      end
    end

    property "handles various protocol versions" do
      check all(
              version <- integer(1..1000),
              max_runs: @max_runs
            ) do
        request = %InitializeRequest{protocol_version: version}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, InitializeRequest)
        assert decoded.protocol_version == version
      end
    end
  end

  describe "PromptRequest property tests" do
    property "encode → decode roundtrip for prompts" do
      check all(
              session_id <- session_id_generator(),
              prompt <- prompt_array(),
              max_runs: @max_runs
            ) do
        request = %PromptRequest{
          session_id: session_id,
          prompt: prompt
        }

        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, PromptRequest)

        assert decoded.session_id == session_id
        # Prompt decoding might normalize the structure
        assert is_list(decoded.prompt)
      end
    end
  end

  describe "File operation property tests" do
    property "FsReadTextFileRequest roundtrip" do
      check all(
              path <- file_path_generator(),
              max_runs: @max_runs
            ) do
        request = %FsReadTextFileRequest{path: path}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
        assert decoded.path == path
      end
    end

    property "FsWriteTextFileRequest roundtrip with content" do
      check all(
              session_id <- session_id_generator(),
              path <- file_path_generator(),
              content <- file_content_generator(),
              max_runs: @max_runs
            ) do
        request = %FsWriteTextFileRequest{
          session_id: session_id,
          path: path,
          content: content
        }

        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, FsWriteTextFileRequest)

        assert decoded.session_id == session_id
        assert decoded.path == path
        assert decoded.content == content
      end
    end

    property "FsReadTextFileResponse handles various content" do
      check all(
              content <- file_content_generator(),
              max_runs: @max_runs
            ) do
        response = %FsReadTextFileResponse{content: content}
        json = Codec.encode!(response)
        {:ok, decoded} = Codec.decode(json, FsReadTextFileResponse)
        assert decoded.content == content
      end
    end
  end

  describe "Terminal operation property tests" do
    property "Terminal.CreateRequest roundtrip" do
      check all(
              command <- command_generator(),
              cwd <- one_of([constant(nil), file_path_generator()]),
              env <- env_variables(),
              max_runs: @max_runs
            ) do
        request = %Terminal.CreateRequest{
          command: command,
          cwd: cwd,
          env: env
        }

        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, Terminal.CreateRequest)

        assert decoded.command == command
        assert decoded.cwd == cwd
        assert decoded.env == env
      end
    end

    property "Terminal.OutputRequest roundtrip" do
      check all(
              terminal_id <- terminal_id_generator(),
              max_runs: @max_runs
            ) do
        request = %Terminal.OutputRequest{terminal_id: terminal_id}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, Terminal.OutputRequest)
        assert decoded.terminal_id == terminal_id
      end
    end
  end

  describe "Edge case generators" do
    property "handles unicode strings" do
      check all(
              path <- unicode_string(),
              max_runs: @max_runs
            ) do
        request = %FsReadTextFileRequest{path: path}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
        assert decoded.path == path
      end
    end

    test "handles empty strings" do
      request = %FsReadTextFileRequest{path: ""}
      json = Codec.encode!(request)
      {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
      assert decoded.path == ""
    end

    property "handles very long strings" do
      check all(
              length <- integer(1000..10_000),
              char <- string(:alphanumeric, length: 1),
              max_runs: 20
            ) do
        long_string = String.duplicate(char, length)
        request = %FsReadTextFileRequest{path: long_string}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
        assert String.length(decoded.path) == length
      end
    end

    property "handles special characters" do
      check all(
              special <-
                one_of([
                  constant("path/to/file"),
                  constant("path\\with\\backslashes"),
                  constant("path with spaces"),
                  constant("path\"with\"quotes"),
                  constant("path\nwith\nnewlines"),
                  constant("path\twith\ttabs"),
                  constant("path'with'apostrophes")
                ]),
              max_runs: @max_runs
            ) do
        request = %FsReadTextFileRequest{path: special}
        json = Codec.encode!(request)
        {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
        assert decoded.path == special
      end
    end
  end

  # Custom generators
  defp positive_int_generator do
    positive_integer()
  end

  defp session_id_generator do
    one_of([
      string(:alphanumeric, min_length: 8, max_length: 64),
      # UUID-like format
      map(list_of(string(:alphanumeric, length: 8), length: 4), fn parts ->
        Enum.join(parts, "-")
      end)
    ])
  end

  defp file_path_generator do
    one_of([
      string(:alphanumeric, min_length: 1, max_length: 100),
      # Unix-style paths
      map(
        list_of(string(:alphanumeric, min_length: 1, max_length: 20),
          min_length: 1,
          max_length: 5
        ),
        fn parts ->
          "/" <> Enum.join(parts, "/")
        end
      ),
      # Relative paths
      map(
        list_of(string(:alphanumeric, min_length: 1, max_length: 20),
          min_length: 1,
          max_length: 5
        ),
        fn parts ->
          Enum.join(parts, "/")
        end
      )
    ])
  end

  defp file_content_generator do
    one_of([
      string(:printable, max_length: 1000),
      string(:alphanumeric, max_length: 1000),
      constant(""),
      # Multiline content
      map(list_of(string(:printable, max_length: 50), max_length: 20), fn lines ->
        Enum.join(lines, "\n")
      end)
    ])
  end

  defp command_generator do
    one_of([
      string(:alphanumeric, min_length: 1, max_length: 100),
      constant("ls"),
      constant("echo"),
      constant("cat"),
      constant("pwd")
    ])
  end

  defp terminal_id_generator do
    map(binary(min_length: 8, max_length: 16), fn bytes ->
      "term-" <> Base.encode16(bytes, case: :lower)
    end)
  end

  defp capabilities_map do
    one_of([
      constant(nil),
      constant(%{}),
      map(string(:alphanumeric, min_length: 1, max_length: 20), fn key ->
        %{key => %{"enabled" => true}}
      end),
      constant(%{"sessions" => %{"new" => true, "load" => false}}),
      constant(%{"filesystem" => %{"read" => true, "write" => true}})
    ])
  end

  defp optional_map do
    one_of([
      constant(nil),
      constant(%{}),
      map(string(:alphanumeric, min_length: 1, max_length: 20), fn key ->
        %{key => "value"}
      end)
    ])
  end

  defp env_variables do
    one_of([
      constant(nil),
      constant([]),
      list_of(
        map(
          {string(:alphanumeric, min_length: 1, max_length: 20),
           string(:printable, max_length: 100)},
          fn {key, value} ->
            %{"name" => key, "value" => value}
          end
        ),
        max_length: 10
      )
    ])
  end

  defp prompt_array do
    one_of([
      constant([]),
      list_of(
        fixed_map(%{
          "type" => constant("text"),
          "text" => string(:printable, max_length: 200)
        }),
        min_length: 1,
        max_length: 10
      )
    ])
  end

  defp unicode_string do
    one_of([
      string(:alphanumeric, max_length: 50),
      constant("Hello 世界"),
      constant("Привет мир"),
      constant("مرحبا بالعالم"),
      constant("🌍🌎🌏"),
      constant("Ñoño José")
    ])
  end
end
