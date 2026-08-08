#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# PostToolUse hook — markdown hard-wrap check
# ─────────────────────────────────────────────────────────────────────────────
# Fires after Edit/Write. If the text just written to a .md file contains lines
# over 77 characters, exit 2 so the message on stderr is fed back to the model,
# which then rewraps. Event reference:
#   https://code.claude.com/docs/en/hooks
#
# Only the NEW text is checked, never the whole file. Several tracked files
# (README.md's AutoHotkey section) have pre-existing 78-80 column lines; a
# whole-file check would fail on every future edit to them and could never be
# satisfied without an unrelated reflow.
#
# Width is counted in CHARACTERS, not bytes -- these files are full of em
# dashes and arrows, and a byte count over-reports them as 3 columns each.
# perl's -CSD decodes stdin as UTF-8 so length() returns characters.
#
# Dependencies: jq (required), perl (required; core on macOS, Linux, WSL).
# ═════════════════════════════════════════════════════════════════════════════

LIMIT=77

input=$(cat)

command -v jq   >/dev/null 2>&1 || exit 0
command -v perl >/dev/null 2>&1 || exit 0

FILE=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

# Only markdown. Anything else -- code, JSON, the statusline -- has its own
# conventions and is none of this hook's business.
case "$FILE" in
  *.md|*.markdown) ;;
  *) exit 0 ;;
esac

# Write sends the full file as .content; Edit sends only the replacement text
# as .new_string. Either way this is exactly the text the model just authored,
# which is the text it can still be asked to fix.
TEXT=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')
[ -z "$TEXT" ] && exit 0

# Fenced code blocks are exempt: wrapping a command or a JSON sample to 77
# columns would change what it means. Track fence state and skip those lines.
OFFENDERS=$(printf '%s' "$TEXT" | perl -CSD -ne '
  chomp;
  if (/^\s*(```|~~~)/) { $fence = !$fence; next }
  next if $fence;
  printf "  %3d cols | %s\n", length($_), $_ if length($_) > '"$LIMIT"';
')

[ -z "$OFFENDERS" ] && exit 0

COUNT=$(printf '%s\n' "$OFFENDERS" | grep -c 'cols |')

{
  echo "Hard-wrap check failed on $FILE — $COUNT line(s) over $LIMIT characters:"
  echo "$OFFENDERS"
  echo "Rewrap these to $LIMIT columns or fewer. Count characters, not bytes."
} >&2

exit 2
