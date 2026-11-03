#!/usr/bin/env bash
#
# Print one scalar from project.yml, addressed by its dotted path. Given several
# paths, prints the first that is set — so a target's own setting can fall back
# to the project-wide one:
#
#   scripts/project-yml.sh targets.BrowBro.settings.base.MARKETING_VERSION \
#                          settings.base.MARKETING_VERSION
#
# Exits 1, naming the paths, when none is set.
#
# Plain awk on purpose. Its callers run where nothing else can be assumed — the
# store workflow before Ruby is set up, the appcast script on a maintainer's Mac
# — and a grep for the first "MARKETING_VERSION:" is exactly what can't tell
# the BrowBro target's version from BrowBroMAS's. This understands the block
# mappings project.yml is written in: indentation, comments, quoted or bare
# scalars. Paths through a list ("- item") are not addressable.
#
# PROJECT_YML overrides the file (default: project.yml at the repository root).
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $0 dotted.path [fallback.path ...]" >&2; exit 2; }
FILE="${PROJECT_YML:-$(dirname "$0")/../project.yml}"
[ -f "$FILE" ] || { echo "error: $FILE not found" >&2; exit 1; }

awk -v wanted="$*" '
  BEGIN { n = split(wanted, want, " ") }
  /^[[:space:]]*(#|$)/ { next }          # comment or blank line
  /^[[:space:]]*- / { next }             # list item
  {
    match($0, /^ */); indent = RLENGTH
    line = substr($0, indent + 1)
    if (!match(line, /^[A-Za-z0-9_.-]+:/)) next
    key = substr(line, 1, RLENGTH - 1)
    value = substr(line, RLENGTH + 1)

    while (depth > 0 && ind[depth] >= indent) depth--
    ind[++depth] = indent; name[depth] = key
    path = name[1]; for (i = 2; i <= depth; i++) path = path "." name[i]

    sub(/^[[:space:]]+/, "", value)
    if (value == "" || value ~ /^#/) next      # opens a nested mapping
    if (value ~ /^"/)      { value = substr(value, 2); sub(/".*$/, "", value) }
    else if (value ~ /^'\''/) { value = substr(value, 2); sub(/'\''.*$/, "", value) }
    else                   { sub(/[[:space:]]+#.*$/, "", value); sub(/[[:space:]]+$/, "", value) }
    found[path] = value
  }
  END {
    for (i = 1; i <= n; i++) if (want[i] in found) { print found[want[i]]; exit 0 }
    exit 1
  }
' "$FILE" || { echo "error: none of [$*] is set in $FILE" >&2; exit 1; }
