#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s INPUT_JSON OUTPUT_JSONC\n' "$(basename "$0")" >&2
}

if (( $# != 2 )); then
  usage
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq is required.\n' >&2
  exit 127
fi

input=$1
output=$2

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/api-request-jsonc.XXXXXX")
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
variableized_json="$work_dir/output.jsonc"

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

jq '
  def sanitize:
    gsub("[^A-Za-z0-9_$]"; "_")
    | if test("^[A-Za-z_$]") then . else "value_" + . end;
  def string_parts($path):
    [$path[] | select(type == "string") | sanitize];
  def leaf_name($path):
    string_parts($path) as $parts
    | if ($parts | length) == 0 then "value" else $parts[-1] end;
  def logical_path_key($path):
    string_parts($path) | join(".");
  def full_path_name($path):
    string_parts($path) as $parts
    | if ($parts | length) == 0 then "value" else ($parts | join("_")) end;
  def placeholder_name($path; $leaf_counts):
    leaf_name($path) as $leaf
    | if (($leaf_counts[$leaf] // 0) == 1) then $leaf else full_path_name($path) end;
  if type == "object" or type == "array" then
    [paths(type != "object" and type != "array")] as $paths
    | ([$paths[] | {leaf: leaf_name(.), key: logical_path_key(.)}]
        | unique_by(.key)
        | reduce .[] as $entry ({}; .[$entry.leaf] = ((.[$entry.leaf] // 0) + 1))) as $leaf_counts
    | reduce $paths[] as $path
      (. ; setpath($path; "${\(placeholder_name($path; $leaf_counts))}"))
  else
    "${value}"
  end
' "$parsed_json" > "$variableized_json"

if [[ "$output" == '-' ]]; then
  cat "$variableized_json"
else
  output_dir=$(dirname "$output")
  mkdir -p "$output_dir"
  output_tmp=$(mktemp "$output_dir/.api-request-jsonc.XXXXXX")
  cp "$variableized_json" "$output_tmp"
  chmod 0644 "$output_tmp"
  mv "$output_tmp" "$output"
  output_tmp=''
fi

placeholder_count=$(jq '[.. | strings | select(test("^\\$\\{[A-Za-z_$][A-Za-z0-9_$]*\\}$"))] | unique | length' "$variableized_json")
root_type=$(jq -r 'type' "$variableized_json")

printf 'Output: %s\n' "$output" >&2
printf 'Root type: %s\n' "$root_type" >&2
printf 'Unique placeholders: %s\n' "$placeholder_count" >&2
