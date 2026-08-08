#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# PreToolUse hook — force a prompt before any git push
# ─────────────────────────────────────────────────────────────────────────────
# Returns permissionDecision "ask" for a Bash command containing a git push, so
# the push always surfaces a confirmation dialog. Event reference:
#   https://code.claude.com/docs/en/hooks
#
# "ask", not "deny": the rule is never push UNLESS asked, so a hard deny would
# also block the times a push was explicitly requested. This removes only the
# silent path -- permissions.defaultMode is "auto", under which a push would
# otherwise run with no confirmation at all.
#
# Detection is done here rather than with an `if` permission rule, because a
# push often arrives inside a compound command (`git commit && git push`) that
# a prefix rule does not match.
#
# Dependencies: jq (required).
# ═════════════════════════════════════════════════════════════════════════════

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# Global options that take a separate value would otherwise sit between `git`
# and `push` and break the match -- `git -C /repo push` is the common one.
# Strip those option/value pairs first, then the match is just flags.
NORM=$(printf '%s' "$CMD" | sed -E 's/[[:space:]]+(-C|-c|--git-dir|--work-tree|--namespace|--exec-path)([[:space:]]+|=)[^[:space:]]+/ /g')

# Matches `git push` anywhere, including inside a compound command.
# Over-matching (the word inside a commit message, say) only costs one extra
# confirmation, so the regex deliberately errs toward asking.
printf '%s' "$NORM" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+)*[[:space:]]+push\b' || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: "git push always needs explicit confirmation"
  }
}'
