# Exclude Claude Code ACP tests by default (require API key and slow)
# Run them with: mix test --only claude_code_acp
ExUnit.start(exclude: [:claude_code_acp])
