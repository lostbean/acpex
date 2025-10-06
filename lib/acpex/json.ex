defmodule ACPex.Json do
  @moduledoc """
  Custom Jason encoder for converting snake_case atoms to camelCase strings.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Jason.Encoder

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
