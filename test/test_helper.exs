# Exclude e2e and external tests by default
# Run them with: mix test --include e2e
ExUnit.start(exclude: [:e2e, :external])
