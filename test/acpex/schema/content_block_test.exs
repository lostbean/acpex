defmodule ACPex.Schema.ContentBlockTest do
  @moduledoc """
  Tests for ContentBlock union type and its variants.
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec
  alias ACPex.Schema.Types.ContentBlock
  alias ACPex.Schema.Types.ContentBlock.{Text, Image, Audio, ResourceLink, Resource}

  describe "ContentBlock.Text" do
    test "encodes with type field" do
      text = %Text{text: "Hello, world!"}

      json = Codec.encode!(text)

      assert json =~ ~s("type":"text")
      assert json =~ ~s("text":"Hello, world!")
    end

    test "decodes from JSON" do
      json = ~s({"type":"text","text":"Test message"})

      {:ok, text} = Codec.decode(json, Text)

      assert text.type == "text"
      assert text.text == "Test message"
    end

    test "validates required fields" do
      changeset = Text.changeset(%{})
      refute changeset.valid?
      assert %{text: [_]} = errors_on(changeset)
    end

    test "validates type field" do
      changeset = Text.changeset(%{type: "wrong", text: "test"})
      refute changeset.valid?
      assert %{type: [_]} = errors_on(changeset)
    end
  end

  describe "ContentBlock.Image" do
    test "encodes with mimeType in camelCase" do
      image = %Image{
        data: "base64data",
        mime_type: "image/png",
        uri: "file:///path/to/image.png"
      }

      json = Codec.encode!(image)

      assert json =~ ~s("type":"image")
      assert json =~ ~s("data":"base64data")
      assert json =~ ~s("mimeType":"image/png")
      assert json =~ ~s("uri":"file:///path/to/image.png")
      refute json =~ "mime_type"
    end

    test "decodes from camelCase JSON" do
      json = ~s({"type":"image","data":"xyz","mimeType":"image/jpeg"})

      {:ok, image} = Codec.decode(json, Image)

      assert image.type == "image"
      assert image.data == "xyz"
      assert image.mime_type == "image/jpeg"
    end

    test "validates required fields" do
      changeset = Image.changeset(%{})
      refute changeset.valid?
      assert %{data: [_], mime_type: [_]} = errors_on(changeset)
    end
  end

  describe "ContentBlock.Audio" do
    test "encodes correctly" do
      audio = %Audio{
        data: "audiobase64",
        mime_type: "audio/wav"
      }

      json = Codec.encode!(audio)

      assert json =~ ~s("type":"audio")
      assert json =~ ~s("data":"audiobase64")
      assert json =~ ~s("mimeType":"audio/wav")
    end

    test "validates required fields" do
      changeset = Audio.changeset(%{})
      refute changeset.valid?
      assert %{data: [_], mime_type: [_]} = errors_on(changeset)
    end
  end

  describe "ContentBlock.ResourceLink" do
    test "encodes with all camelCase fields" do
      link = %ResourceLink{
        uri: "file:///doc.pdf",
        name: "document.pdf",
        title: "Important Document",
        description: "A PDF file",
        mime_type: "application/pdf",
        size: 1024
      }

      json = Codec.encode!(link)

      assert json =~ ~s("type":"resource_link")
      assert json =~ ~s("uri":"file:///doc.pdf")
      assert json =~ ~s("name":"document.pdf")
      assert json =~ ~s("title":"Important Document")
      assert json =~ ~s("mimeType":"application/pdf")
      assert json =~ ~s("size":1024)
    end

    test "validates required fields" do
      changeset = ResourceLink.changeset(%{})
      refute changeset.valid?
      assert %{uri: [_], name: [_]} = errors_on(changeset)
    end

    test "validates size is non-negative" do
      changeset = ResourceLink.changeset(%{uri: "x", name: "y", size: -1})
      refute changeset.valid?
      assert %{size: [_]} = errors_on(changeset)
    end
  end

  describe "ContentBlock.Resource" do
    test "encodes with resource field" do
      resource = %Resource{
        resource: %{"uri" => "file:///test.txt", "text" => "content", "mimeType" => "text/plain"}
      }

      json = Codec.encode!(resource)

      assert json =~ ~s("type":"resource")
      assert json =~ ~s("resource":)
      assert json =~ ~s("uri":"file:///test.txt")
    end

    test "validates resource has required fields" do
      changeset = Resource.changeset(%{resource: %{"uri" => "x", "text" => "y"}})
      assert changeset.valid?

      changeset = Resource.changeset(%{resource: %{"uri" => "x", "blob" => "y"}})
      assert changeset.valid?

      changeset = Resource.changeset(%{resource: %{"invalid" => "structure"}})
      refute changeset.valid?
      assert %{resource: [_]} = errors_on(changeset)
    end
  end

  describe "ContentBlock union decoder" do
    test "decodes text variant" do
      json = ~s({"type":"text","text":"Hello"})

      {:ok, block} = ContentBlock.decode(json)

      assert %Text{text: "Hello"} = block
    end

    test "decodes image variant" do
      json = ~s({"type":"image","data":"xyz","mimeType":"image/png"})

      {:ok, block} = ContentBlock.decode(json)

      assert %Image{data: "xyz", mime_type: "image/png"} = block
    end

    test "decodes audio variant" do
      json = ~s({"type":"audio","data":"abc","mimeType":"audio/wav"})

      {:ok, block} = ContentBlock.decode(json)

      assert %Audio{data: "abc", mime_type: "audio/wav"} = block
    end

    test "decodes resource_link variant" do
      json = ~s({"type":"resource_link","uri":"file:///x","name":"file.txt"})

      {:ok, block} = ContentBlock.decode(json)

      assert %ResourceLink{uri: "file:///x", name: "file.txt"} = block
    end

    test "decodes resource variant" do
      json = ~s({"type":"resource","resource":{"uri":"file:///x","text":"content"}})

      {:ok, block} = ContentBlock.decode(json)

      assert %Resource{} = block
    end

    test "returns error for unknown type" do
      {:error, msg} = ContentBlock.decode(%{"type" => "unknown"})
      assert msg =~ "Unknown content block type"
    end

    test "returns error for missing type" do
      {:error, msg} = ContentBlock.decode(%{"text" => "hello"})
      assert msg =~ "Missing type field"
    end

    test "decode! raises on error" do
      assert_raise ArgumentError, fn ->
        ContentBlock.decode!(%{"type" => "unknown"})
      end
    end
  end

  # Helper function to convert changeset errors to a map
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
