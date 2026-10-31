#!/usr/bin/env bash

R=$'\033[0m'
B=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
GRAY=$'\033[90m'
BRED=$'\033[91m'
BGREEN=$'\033[92m'
BYELLOW=$'\033[93m'
BMAGENTA=$'\033[95m'
BCYAN=$'\033[96m'
BWHITE=$'\033[97m'

SEP=" ${GRAY}·${R} "

INPUT=$(cat 2>/dev/null || true)

DATA=$(printf '%s' "$INPUT" | jq -r '
def trunc($n):
  if length > $n then .[0:($n - 1)] + "…" else . end;

def human_secs:
  if . == null then ""
  elif . < 60 then "<1m"
  elif . < 3600 then "\(. / 60 | floor)m"
  elif . < 86400 then "\(. / 3600 | floor)h \(. % 3600 / 60 | floor)m"
  else "\(. / 86400 | floor)d \(. % 86400 / 3600 | floor)h"
  end;

def bucket_info($id):
  if $id == "weekly" or $id == "gemini-weekly" then
    {go: 0, g: "Gemini", o: 0, l: "weekly"}
  elif $id == "5h" or $id == "gemini-5h" then
    {go: 0, g: "Gemini", o: 1, l: "5h"}
  elif $id == "3p-weekly" or $id == "claude-weekly" or $id == "gpt-weekly" then
    {go: 1, g: "Claude/GPT", o: 0, l: "weekly"}
  elif $id == "3p-5h" or $id == "claude-5h" or $id == "gpt-5h" then
    {go: 1, g: "Claude/GPT", o: 1, l: "5h"}
  elif $id == "argon-wtu-weekly" or $id == "argon-weekly" then
    {go: 2, g: "Argon", o: 0, l: "weekly"}
  elif ($id | startswith("gemini-")) then
    {go: 0, g: "Gemini", o: 9, l: ($id | sub("^gemini-"; ""))}
  elif ($id | startswith("3p-")) then
    {go: 1, g: "Claude/GPT", o: 9, l: ($id | sub("^3p-"; ""))}
  elif ($id | startswith("claude-")) or ($id | startswith("gpt-")) then
    {go: 1, g: "Claude/GPT", o: 9, l: ($id | sub("^(claude|gpt)-"; ""))}
  elif ($id | startswith("argon-")) then
    {go: 2, g: "Argon", o: 9, l: ($id | sub("^argon-"; ""))}
  else
    {go: 3, g: "Other", o: 9, l: ($id | gsub("-"; " "))}
  end;

def quota_groups($show_reset):
  [ (.quota // {}) | to_entries[]
    | select(.value.disabled != true)
    | .key as $id
    | .value as $q
    | bucket_info($id) as $b
    | ( if $q.remaining_fraction != null then
          ((($q.remaining_fraction | tonumber) * 100) | round) as $p
          | {amt: "\($p)%", pct: $p}
        elif $q.remaining_amount != null then
          {amt: "\($q.remaining_amount) left", pct: null}
        else empty end ) as $a
    | ( if $show_reset and ($q.reset_in_seconds != null) and (($a.pct // 0) < 100) then
          " ↻ \(($q.reset_in_seconds | tonumber) | human_secs)"
        else "" end ) as $reset
    | {go: $b.go, o: $b.o, g: $b.g, s: "\($b.l) \($a.amt)\($reset)"}
  ]
  | sort_by(.go, .o)
  | group_by(.go)
  | map("\(.[0].g): " + (map(.s) | join(" · ")))
  | join("\u001e");

(.context_window // {}) as $cw
| ($cw.total_input_tokens // 0) as $in
| ($cw.total_output_tokens // 0) as $out
| ($cw.context_window_size // 0) as $size
| ($cw.used_percentage // 0) as $pct
| ((.conversation_title // "") | tostring | gsub("[[:cntrl:]]"; " ") | gsub(" +"; " ") | sub("^ +"; "") | sub(" +$"; "")) as $raw_title
| (if $raw_title == "" then "untitled" else $raw_title end) as $title
| [
    (.cycle_mode // ""),
    (.model.display_name // ""),
    (.model.effort // ""),
    ($title | trunc(40)),
    ($title | trunc(30)),
    ($title | trunc(24)),
    ($title | trunc(18)),
    ($title | trunc(14)),
    ($title | trunc(10)),
    ($title | trunc(6)),
    ($in | tostring),
    ($out | tostring),
    ($size | tostring),
    ($pct | tostring),
    quota_groups(true),
    quota_groups(false),
    ((.terminal_width // 80) | tostring)
  ]
| join("\u001f")
' 2>/dev/null) || DATA=""

MODE=""
MODEL=""
EFFORT=""
TITLE_40="untitled"
TITLE_30="untitled"
TITLE_24="untitled"
TITLE_18="untitled"
TITLE_14="untitled"
TITLE_10="untitled"
TITLE_6="untitled"
IN=0
OUT=0
SIZE=0
PCT=0
QUOTA_FULL_RAW=""
QUOTA_SHORT_RAW=""
COLS=80

if [[ -n "$DATA" ]]; then
  IFS=$'\x1f' read -r MODE MODEL EFFORT TITLE_40 TITLE_30 TITLE_24 TITLE_18 TITLE_14 TITLE_10 TITLE_6 IN OUT SIZE PCT QUOTA_FULL_RAW QUOTA_SHORT_RAW COLS <<< "$DATA"
fi

[[ "$IN" =~ ^[0-9]+$ ]] || IN=0
[[ "$OUT" =~ ^[0-9]+$ ]] || OUT=0
[[ "$SIZE" =~ ^[0-9]+$ ]] || SIZE=0
[[ "$PCT" =~ ^[0-9]+([.][0-9]+)?$ ]] || PCT=0
[[ "$COLS" =~ ^[0-9]+$ ]] || COLS=80
(( COLS > 0 )) || COLS=80

MODE=${MODE,,}
case "$MODE" in
  plan) MODE_LABEL="PLAN"; MODE_COLOR=$BCYAN ;;
  auto) MODE_LABEL="AUTO"; MODE_COLOR=$BYELLOW ;;
  accept-edits) MODE_LABEL="EDITS"; MODE_COLOR=$BGREEN ;;
  *) MODE_LABEL="DEFAULT"; MODE_COLOR=$GRAY ;;
esac

MODEL_NAME="$MODEL"
EFFORT=${EFFORT,,}
if [[ -n "$EFFORT" && "$MODEL" =~ ^(.*)[[:space:]]\(([^()]*)\)$ ]]; then
  if [[ "${BASH_REMATCH[2],,}" == "$EFFORT" ]]; then
    MODEL_NAME="${BASH_REMATCH[1]}"
  fi
fi

IDENTITY="${MODE_COLOR}${B}${MODE_LABEL}${R}"
if [[ -n "$MODEL_NAME" ]]; then
  IDENTITY+="${SEP}${BMAGENTA}${ITALIC}${MODEL_NAME}${R}"
  [[ -n "$EFFORT" ]] && IDENTITY+="${SEP}${DIM}${EFFORT}${R}"
fi

PCT_FMT=$(LC_NUMERIC=C printf '%.1f' "$PCT" 2>/dev/null) || PCT_FMT="0.0"
PCT_INT=${PCT_FMT%.*}
[[ "$PCT_INT" =~ ^[0-9]+$ ]] || PCT_INT=0

if (( PCT_INT >= 85 )); then
  CTX_COLOR=$BRED
elif (( PCT_INT >= 60 )); then
  CTX_COLOR=$BYELLOW
else
  CTX_COLOR=$BWHITE
fi

BAR_LEN=8
FILLED=$(( PCT_INT * BAR_LEN / 100 ))
REM=$(( (PCT_INT * BAR_LEN) % 100 ))
BAR=""
for ((i = 0; i < BAR_LEN; i++)); do
  if (( i < FILLED )); then
    BAR+="█"
  elif (( i == FILLED )); then
    if (( REM >= 75 )); then BAR+="▓"
    elif (( REM >= 50 )); then BAR+="▒"
    elif (( REM >= 25 )); then BAR+="░"
    else BAR+="·"
    fi
  else
    BAR+="·"
  fi
done

fmt_tokens() {
  local n=${1:-0}
  if (( n >= 999500 )); then
    local t=$(( (n + 50000) / 100000 ))
    printf '%d.%dM' $(( t / 10 )) $(( t % 10 ))
  elif (( n >= 1000 )); then
    printf '%dk' $(( (n + 500) / 1000 ))
  else
    printf '%d' "$n"
  fi
}

USED=$(( IN + OUT ))
if (( SIZE > 0 )); then
  CTX="${DIM}ctx${R} ${CTX_COLOR}${BAR}${R} ${B}${PCT_FMT}%${R} ${DIM}$(fmt_tokens "$USED")/$(fmt_tokens "$SIZE")${R}"
  CTX_PLAIN="ctx ${BAR} ${PCT_FMT}% $(fmt_tokens "$USED")/$(fmt_tokens "$SIZE")"
elif (( USED > 0 )); then
  CTX="${DIM}ctx${R} ${B}${PCT_FMT}%${R} ${DIM}$(fmt_tokens "$USED") tok${R}"
  CTX_PLAIN="ctx ${PCT_FMT}% $(fmt_tokens "$USED") tok"
else
  CTX="${DIM}ctx —${R}"
  CTX_PLAIN="ctx —"
fi

IDENTITY_PLAIN="$MODE_LABEL"
[[ -n "$MODEL_NAME" ]] && IDENTITY_PLAIN+=" · ${MODEL_NAME}"
[[ -n "$EFFORT" ]] && IDENTITY_PLAIN+=" · ${EFFORT}"

QUOTA_FULL_GROUPS=()
QUOTA_SHORT_GROUPS=()
if [[ -n "$QUOTA_FULL_RAW" ]]; then
  IFS=$'\x1e' read -r -a QUOTA_FULL_GROUPS <<< "$QUOTA_FULL_RAW"
fi
if [[ -n "$QUOTA_SHORT_RAW" ]]; then
  IFS=$'\x1e' read -r -a QUOTA_SHORT_GROUPS <<< "$QUOTA_SHORT_RAW"
fi

pick_title() {
  local max=$1
  if (( max >= 40 )); then printf '%s' "$TITLE_40"
  elif (( max >= 30 )); then printf '%s' "$TITLE_30"
  elif (( max >= 24 )); then printf '%s' "$TITLE_24"
  elif (( max >= 18 )); then printf '%s' "$TITLE_18"
  elif (( max >= 14 )); then printf '%s' "$TITLE_14"
  elif (( max >= 10 )); then printf '%s' "$TITLE_10"
  else printf '%s' "$TITLE_6"
  fi
}

if (( COLS < 80 )); then
  TITLE_MAX=$(( COLS - ${#CTX_PLAIN} - 3 ))
  QUOTA_GROUPS=("${QUOTA_SHORT_GROUPS[@]}")
else
  TITLE_MAX=$(( COLS - ${#IDENTITY_PLAIN} - ${#CTX_PLAIN} - 6 ))
  if (( COLS >= 120 )); then
    QUOTA_GROUPS=("${QUOTA_FULL_GROUPS[@]}")
  else
    QUOTA_GROUPS=("${QUOTA_SHORT_GROUPS[@]}")
  fi
fi
(( TITLE_MAX > 40 )) && TITLE_MAX=40
(( TITLE_MAX < 6 )) && TITLE_MAX=6

TITLE_TEXT=$(pick_title "$TITLE_MAX")
TITLE_SEG="${DIM}${TITLE_TEXT}${R}"

QUOTA_MAX_NAME=0
for g in "${QUOTA_GROUPS[@]}"; do
  [[ -z "$g" ]] && continue
  gname="${g%%:*}"
  (( ${#gname} > QUOTA_MAX_NAME )) && QUOTA_MAX_NAME=${#gname}
done

if (( COLS < 80 )); then
  printf '%s\n%s\n' "$IDENTITY" "${TITLE_SEG}${SEP}${CTX}"
else
  printf '%s\n' "${IDENTITY}${SEP}${TITLE_SEG}${SEP}${CTX}"
fi

if (( ${#QUOTA_GROUPS[@]} > 0 )); then
  count=${#QUOTA_GROUPS[@]}
  for ((qi = 0; qi < count; qi++)); do
    g="${QUOTA_GROUPS[qi]}"
    if [[ "$g" == *": "* ]]; then
      gname="${g%%:*}"
      entries="${g#*: }"
    else
      gname="Other"
      entries="$g"
    fi
    case "$gname" in
      Gemini) gcolor=$BCYAN ;;
      "Claude/GPT") gcolor=$BMAGENTA ;;
      Argon) gcolor=$BYELLOW ;;
      *) gcolor=$GRAY ;;
    esac
    printf -v padded '%-*s' "$QUOTA_MAX_NAME" "$gname"
    if (( qi == count - 1 )); then marker="└"; else marker="├"; fi
    line="${GRAY}${marker}${R} ${B}${gcolor}${padded}${R}  ${BWHITE}${entries}${R}"
    if (( qi == 0 )); then
      printf '%s  %s\n' "${GRAY}limits${R}" "$line"
    else
      printf '        %s\n' "$line"
    fi
  done
fi

exit 0
