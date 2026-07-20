#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT_JSON OUTPUT_JSONC [JQ_FILTER]\n' "$(basename "$0")" >&2
}

if (( $# < 2 || $# > 3 )); then
  usage
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq is required.\n' >&2
  exit 127
fi

input=$1
output=$2
payload_filter=${3:-.}

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/api-response-jsonc.XXXXXX")
output_tmp=''
cleanup() {
  rm -rf "$work_dir"
  if [[ -n "$output_tmp" && -f "$output_tmp" ]]; then
    rm -f "$output_tmp"
  fi
}
trap cleanup EXIT

source_json="$work_dir/source.json"
parsed_json="$work_dir/parsed.json"
selected_json="$work_dir/selected.json"
annotated_jsonc="$work_dir/output.jsonc"

if [[ "$input" == '-' ]]; then
  cp /dev/stdin "$source_json"
elif [[ -f "$input" ]]; then
  cp "$input" "$source_json"
else
  printf 'Error: input file not found: %s\n' "$input" >&2
  exit 1
fi

if ! jq -s '
  if length == 1 then .[0]
  else error("input must contain exactly one JSON document")
  end
' "$source_json" > "$parsed_json"; then
  printf 'Error: input is not a single valid JSON document.\n' >&2
  exit 1
fi

if ! jq "[$payload_filter] |
  if length == 1 then .[0]
  else error(\"JQ_FILTER must produce exactly one JSON value\")
  end
" "$parsed_json" > "$selected_json"; then
  printf 'Error: failed to apply JQ_FILTER: %s\n' "$payload_filter" >&2
  exit 1
fi

awk '
  {
    line = $0
    if (match(line, /^[[:space:]]*"[^"]+"[[:space:]]*:/)) {
      value = line
      sub(/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*/, "", value)
      if (value ~ /^"/) value_type = "String"
      else if (value ~ /^(true|false)(,)?$/) value_type = "Boolean"
      else if (value ~ /^null(,)?$/) value_type = "Null"
      else if (value ~ /^\[/) value_type = "Array"
      else if (value ~ /^\{/) value_type = "Object"
      else value_type = "Number"
      line = line " // 含义待确认，" value_type
    }
    print line
  }
' "$selected_json" > "$annotated_jsonc"

if [[ "$output" == '-' ]]; then
  cat "$annotated_jsonc"
else
  output_dir=$(dirname "$output")
  mkdir -p "$output_dir"
  output_tmp=$(mktemp "$output_dir/.api-response-jsonc.XXXXXX")
  cp "$annotated_jsonc" "$output_tmp"
  chmod 0644 "$output_tmp"
  mv "$output_tmp" "$output"
  output_tmp=''
fi

root_type=$(jq -r 'type' "$selected_json")
field_count=$(jq '[.. | objects | keys_unsorted[]] | length' "$selected_json")

printf 'Output: %s\n' "$output" >&2
printf 'JQ filter: %s\n' "$payload_filter" >&2
printf 'Root type: %s\n' "$root_type" >&2
printf 'Object fields: %s\n' "$field_count" >&2
