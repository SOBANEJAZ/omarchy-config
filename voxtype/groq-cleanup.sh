#!/usr/bin/env bash
set -euo pipefail

# Flatten newlines/tabs/extra spaces into single spaces so typed output never
# triggers Enter mid-sentence (whisper emits \n at every segment boundary).
flatten() {
  tr '\n\t' '  ' | sed 's/   */ /g; s/^ //; s/ $//'
}

INPUT=$(cat | flatten)

if [ -z "$INPUT" ]; then
  exit 0
fi

KEY=$(sed -n 's/.*remote_api_key = "\(gsk_[A-Za-z0-9]*\)".*/\1/p' "$HOME/.config/voxtype/config.toml" | head -1)

if [ -z "$KEY" ]; then
  printf '%s\n' "$INPUT"
  exit 0
fi

PAYLOAD=$(jq -n --arg user "$INPUT" '{
  model: "openai/gpt-oss-20b",
  reasoning_effort: "medium",
  temperature: 0.1,
  messages: [
    {role: "system", content: "You are a dictation post-processor. The speaker is a software developer who dictates developer content and technical terms. Receive raw speech-to-text output and return clean, polished text ready to be typed: remove filler words (um, uh, like, you know, I mean), fix spelling, grammar and punctuation, and keep technical terms intact. Output ONLY the cleaned text - no quotes, no emojis, no explanations."},
    {role: "user", content: $user}
  ]
}')

CLEANED=$(curl -s --max-time 25 https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  --data-binary "$PAYLOAD" | jq -r '.choices[0].message.content // empty' || true)

if [ -z "$CLEANED" ] || [ "$CLEANED" = "null" ]; then
  printf '%s\n' "$INPUT"
else
  printf '%s\n' "$(printf '%s' "$CLEANED" | flatten)"
fi