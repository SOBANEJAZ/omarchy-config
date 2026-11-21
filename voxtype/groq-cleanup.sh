#!/usr/bin/env bash
set -euo pipefail

# Flatten newlines/tabs/extra spaces into single spaces so typed output never
# triggers Enter mid-sentence (whisper emits \n at every segment boundary).
flatten() {
  tr '\n\t' '  ' | sed 's/   */ /g; s/^ //; s/ $//'
}

read_dict() {
  local file=$1
  [[ -f $file ]] || return 0
  awk '
    {
      sub(/\r$/, "")
      sub(/^[ \t]+/, "")
      sub(/[ \t]+$/, "")
      if ($0 != "" && substr($0, 1, 1) != "#") print "- " $0
    }
  ' "$file"
}

INPUT=$(cat | flatten)

if [ -z "$INPUT" ]; then
  exit 0
fi

VOXTYPE_DIR="$HOME/.config/voxtype"
KEY=$(sed -n 's/.*remote_api_key = "\(gsk_[A-Za-z0-9]*\)".*/\1/p' "$VOXTYPE_DIR/config.toml" | head -1)

if [ -z "$KEY" ]; then
  printf '%s\n' "$INPUT"
  exit 0
fi

DEFAULT_PROMPT='You are a dictation post-processor. The speaker is a software developer who dictates developer content and technical terms. Receive raw speech-to-text output and return clean, polished text ready to be typed: remove filler words (um, uh, like, you know, I mean), fix spelling, grammar, and punctuation, and keep technical terms intact. Output ONLY the cleaned text — no quotes, no emojis, no explanations.'

SYSTEM_PROMPT=""
if [[ -s $VOXTYPE_DIR/prompt.txt ]]; then
  SYSTEM_PROMPT=$(awk '
    { sub(/\r$/, ""); lines = lines (NR > 1 ? "\n" : "") $0 }
    END { sub(/^[ \t\n]+/, "", lines); sub(/[ \t\n]+$/, "", lines); printf "%s", lines }
  ' "$VOXTYPE_DIR/prompt.txt")
fi
SYSTEM_PROMPT="${SYSTEM_PROMPT:-$DEFAULT_PROMPT}"

NL=$'\n'
DICT_ENTRIES=""
for dict_file in "$VOXTYPE_DIR/dictionary.txt" "$VOXTYPE_DIR/dictionary.local.txt"; do
  entries=$(read_dict "$dict_file")
  if [[ -n $entries ]]; then
    if [[ -n $DICT_ENTRIES ]]; then
      DICT_ENTRIES+="$NL$entries"
    else
      DICT_ENTRIES="$entries"
    fi
  fi
done

if [[ -n $DICT_ENTRIES ]]; then
  SYSTEM_PROMPT+="${NL}${NL}Preferred spellings (when raw speech sounds close to a term below, use the exact spelling):${NL}${DICT_ENTRIES}"
fi

PAYLOAD=$(jq -n --arg system "$SYSTEM_PROMPT" --arg user "$INPUT" '{
  model: "qwen/qwen3.8-27b",
  reasoning_effort: "medium",
  reasoning_format: "hidden",
  temperature: 0.1,
  messages: [
    {role: "system", content: $system},
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
