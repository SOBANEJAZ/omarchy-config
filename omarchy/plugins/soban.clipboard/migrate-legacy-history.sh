#!/bin/bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
history_path="$state_dir/clipboard-history.json"
image_dir="$state_dir/clipboard-images"
cliphist_db="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/db"
elephant_image_dir="${XDG_CACHE_HOME:-$HOME/.cache}/elephant/clipboardimages"

mkdir -p "$image_dir"
[[ -r $history_path ]] || printf '[]\n' >"$history_path"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

import_path="$work_dir/imported.jsonl"
: >"$import_path"
imported=0

append_text() {
  local source="$1"
  local entry_path="$work_dir/entry.json"

  [[ -s $source ]] || return 0
  jq -c -Rs 'select((gsub("[[:space:]]"; "") | length) > 0) | {type:"text", text:.}' \
    "$source" >"$entry_path" 2>/dev/null || return 0
  [[ -s $entry_path ]] || return 0

  cat "$entry_path" >>"$import_path"
  imported=$((imported + 1))
}

append_image() {
  local source="$1"
  local mime ext hash target

  [[ -f $source ]] || return 0
  mime=$(file -b --mime-type "$source" 2>/dev/null || true)
  [[ $mime == image/* ]] || return 0

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg
  hash=$(sha256sum "$source" | cut -d ' ' -f 1)
  target="$image_dir/$hash.$ext"

  if [[ ! -e $target ]]; then
    cp --reflink=auto "$source" "$target"
  fi

  jq -cn --arg mime "$mime" --arg path "$target" \
    '{type:"image", mime:$mime, path:$path}' >>"$import_path"
  imported=$((imported + 1))
}

if [[ -r $cliphist_db ]] && command -v cliphist >/dev/null 2>&1; then
  while IFS= read -r record; do
    [[ -n $record ]] || continue
    decoded="$work_dir/decoded"
    if ! printf '%s\n' "$record" | cliphist -db-path "$cliphist_db" decode >"$decoded" 2>/dev/null; then
      continue
    fi

    mime=$(file -b --mime-type "$decoded" 2>/dev/null || true)
    if [[ $mime == image/* ]]; then
      append_image "$decoded"
    elif [[ $mime == text/* || $mime == application/json || $mime == application/xml ]]; then
      append_text "$decoded"
    fi
  done < <(cliphist -db-path "$cliphist_db" list 2>/dev/null || true)
fi

if [[ -d $elephant_image_dir ]]; then
  while IFS= read -r -d '' image; do
    append_image "$image"
  done < <(
    for image in "$elephant_image_dir"/*; do
      [[ -f $image ]] || continue
      printf '%s\0' "$image"
    done | sort -z -r
  )
fi

merged_path="$work_dir/merged.json"
jq -n --slurpfile current "$history_path" --slurpfile imported "$import_path" '
  def same($left; $right):
    $left.type == $right.type and (
      ($left.type == "text" and $left.text == $right.text) or
      ($left.type == "image" and $left.path == $right.path)
    );

  reduce (($current[0] // []) + $imported)[] as $entry ([ ];
    if any(.[]; same(.; $entry)) then . else . + [$entry] end
  )
' >"$merged_path"

mv "$merged_path" "$history_path"

printf 'Imported %s legacy records; history now contains %s entries.\n' \
  "$imported" "$(jq 'length' "$history_path")"
