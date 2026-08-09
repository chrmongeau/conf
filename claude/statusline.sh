#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# Claude Code statusline
# ─────────────────────────────────────────────────────────────────────────────
# Reads JSON from stdin (piped in by Claude Code on each update) and prints a
# two-line status bar. Field reference:
#   https://code.claude.com/docs/en/statusline#available-data
#
# Dependencies:
#   - jq   (REQUIRED) — JSON parser. Script aborts with a warning if missing.
#   - git  (OPTIONAL) — for branch + dirty-state segment. Without it, the git
#                       segment is replaced by "(git missing)".
#   Other tools used (printf, cut, wc, tr, date, command) are POSIX utilities
#   present by default on macOS, Linux, and WSL.
# ═════════════════════════════════════════════════════════════════════════════

input=$(cat)

# ─── Dependency check ────────────────────────────────────────────────────────
# This script depends on `jq` for parsing the JSON Claude Code pipes in. If
# it's missing we print a clear one-line warning instead of a broken
# statusline full of empty fields, then exit 0 so Claude Code doesn't blank
# the bar entirely.
if ! command -v jq >/dev/null 2>&1; then
  RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'
  echo -e "${RED}[statusline]${RESET} ${YELLOW}jq not found${RESET} — install it: ${YELLOW}sudo apt install jq${RESET} (Debian/Ubuntu/WSL) or ${YELLOW}brew install jq${RESET} (macOS)"
  exit 0
fi

# ─── Extract fields from Claude Code's JSON ──────────────────────────────────

# One jq pass, not one per field. Each spawn costs a few milliseconds and
# there are fourteen fields; a single @tsv line read into variables is the
# whole extraction. Field ORDER here must match the read below.
#
# Two traps here, both of which silently shift every later field by one:
#   - `// ""`, never `// empty`: inside an array, `empty` REMOVES the element
#     rather than blanking it.
#   - readarray over one-value-per-line, not `read` with IFS=$'\t'. Tab is
#     IFS whitespace, so bash collapses runs of it — two adjacent empty
#     fields would silently become one.
#
#   MODEL         .model.display_name — e.g. "Opus", "Sonnet 4.6"
#   DIR           cwd; only the basename is displayed (${DIR##*/})
#   PCT           % of the CONVERSATION context window used (0–100). NOT the
#                 Max plan quota — that is FIVE_H / WEEK. Floored to an int.
#   DURATION_MS   wall-clock since session start, idle time included
#   COST          notional API cost in USD this session WOULD have cost on
#                 pay-per-token billing. On a Max/Pro plan you do not pay it.
#   LINES_*       cumulative lines added/removed via Edit/Write this session
#   EFFORT        reasoning effort; reflects live /effort changes. Absent on
#                 models without the parameter.
#   OUTPUT_STYLE  shown only when not "default", to avoid clutter
#   FIVE_H/WEEK   % of the Max plan's 5-hour and 7-day rolling windows, the
#                 same numbers as claude.ai/settings/usage. The 5h window is
#                 rolling — it resets 5h after the window's first message,
#                 not on wall-clock boundaries. Absent until the first API
#                 response of the session.
#   *_RESET       Unix epoch seconds when each window resets; fmt_reset()
#                 renders the countdown
#   TRANSCRIPT    this session's .jsonl. The payload has no skill or plugin
#                 field (see the docs' "Available data" table), so invoked
#                 skills can only be recovered by reading the transcript.
readarray -t F < <(printf '%s' "$input" | jq -r '[
  .model.display_name // "null",
  .workspace.current_dir // "null",
  (.context_window.used_percentage // 0 | floor),
  .cost.total_duration_ms // 0,
  .cost.total_cost_usd // 0,
  .cost.total_lines_added // 0,
  .cost.total_lines_removed // 0,
  .effort.level // "",
  .output_style.name // "",
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.resets_at // "",
  .transcript_path // ""
] | .[]')

MODEL=${F[0]}        DIR=${F[1]}           PCT=${F[2]}
DURATION_MS=${F[3]}  COST=${F[4]}
LINES_ADDED=${F[5]}  LINES_REMOVED=${F[6]}
EFFORT=${F[7]}       OUTPUT_STYLE=${F[8]}
FIVE_H=${F[9]}       WEEK=${F[10]}
FIVE_H_RESET=${F[11]} WEEK_RESET=${F[12]}
TRANSCRIPT=${F[13]}

# ─── ANSI color codes ────────────────────────────────────────────────────────
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
DIM='\033[2m'; BOLD='\033[1m'; MAGENTA='\033[35m'; RESET='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────

# pick_color: green <70%, yellow 70–89%, red ≥90%. Used for any 0–100 metric
# where higher = closer to a limit (context, plan windows).
pick_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then echo "$RED"
  elif [ "$pct" -ge 70 ]; then echo "$YELLOW"
  else echo "$GREEN"; fi
}

# bar: render a 10-char unicode progress bar for a 0–100 percentage.
# Filled with █, empty with ░.
bar() {
  local pct=$1
  local width=10
  local filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$((width - filled))
  local fill="" pad=""
  [ "$filled" -gt 0 ] && printf -v fill "%${filled}s" && fill="${fill// /█}"
  [ "$empty"  -gt 0 ] && printf -v pad  "%${empty}s"  && pad="${pad// /░}"
  echo "${fill}${pad}"
}

# fmt_duration: collapse milliseconds to at most two units, largest first, so
# a long session reads "1d0h" instead of "1450m45s". Seconds appear only below
# the hour mark — past that they are noise, and dropping them keeps the field
# from growing as the session ages. No space between units, unlike fmt_reset
# below, because this sits inline rather than in its own parenthesis.
fmt_duration() {
  local total=$(($1 / 1000))
  local d=$((total / 86400))
  local h=$(((total % 86400) / 3600))
  local m=$(((total % 3600) / 60))
  local s=$((total % 60))
  if   [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  elif [ "$m" -gt 0 ]; then echo "${m}m${s}s"
  else                      echo "${s}s"
  fi
}

# fmt_reset: turn a future Unix epoch into a compact "0 in Xh Ym" string
# (or "0 in Xd Yh" once we're more than 24h out). Used for both rate-limit
# window countdowns. Silently returns nothing if the input is empty or the
# target time has already passed.
fmt_reset() {
  local target=$1
  [ -z "$target" ] && return
  local now=$(date +%s)
  local diff=$((target - now))
  [ "$diff" -le 0 ] && return
  local h=$((diff / 3600))
  local m=$(((diff % 3600) / 60))
  if [ "$h" -ge 24 ]; then
    local d=$((h / 24)); local hr=$((h % 24))
    echo " ${DIM}(0 in ${d}d ${hr}h)${RESET}"
  else
    echo " ${DIM}(0 in ${h}h ${m}m)${RESET}"
  fi
}

# ─── Build display segments ──────────────────────────────────────────────────

# CTX_COLOR / CTX_BAR: visual indicator for the conversation context window.
CTX_COLOR=$(pick_color "$PCT")
CTX_BAR=$(bar "$PCT")

# GIT_INFO: branch name + colored counters for staged (+), modified (~), and
# untracked (?) files. Three possible states:
#   1. `git` not installed              → show a dim "(git missing)" hint
#   2. `git` installed, cwd not a repo  → empty string (most common case)
#   3. `git` installed, cwd is a repo   → branch + counters
GIT_INFO=""
if ! command -v git >/dev/null 2>&1; then
  GIT_INFO=" | ${DIM}(git missing)${RESET}"
elif git --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git --no-optional-locks branch --show-current 2>/dev/null)
  STAGED=$(git --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  MODIFIED=$(git --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  UNTRACKED=$(git --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  GIT_INFO=" | 🌿 ${BRANCH}"
  [ "$STAGED" -gt 0 ]    && GIT_INFO="${GIT_INFO} ${GREEN}+${STAGED}${RESET}"
  [ "$MODIFIED" -gt 0 ]  && GIT_INFO="${GIT_INFO} ${YELLOW}~${MODIFIED}${RESET}"
  [ "$UNTRACKED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${RED}?${UNTRACKED}${RESET}"
fi

# DURATION: session wall-clock, collapsed to its two largest useful units.
DURATION=$(fmt_duration "$DURATION_MS")

# DIFF_INFO: "+lines/-lines" summary, only shown if anything changed.
DIFF_INFO=""
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
  DIFF_INFO=" | ${GREEN}+${LINES_ADDED}${RESET}/${RED}-${LINES_REMOVED}${RESET}"
fi

# SKILLS_INFO: how many DISTINCT skills have fired. Skills are invocations,
# not modes -- there is no "active" set to report -- so this is a count of what
# has run, not of what is running.
#
# Only the tail of the transcript is scanned: these files reach several MB and
# this script runs on every refresh, so a full scan would be paid many times a
# minute. At 400 KB the whole segment measures ~35ms, most of it the extra jq
# spawn rather than the scan. The cost is that a skill used early in a long
# session drops out, which is why the count means "recently", not "this
# session". Raise SKILL_SCAN_BYTES to trade latency for reach.
SKILL_SCAN_BYTES=400000
SKILLS_INFO=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  SKILL_COUNT=$(tail -c "$SKILL_SCAN_BYTES" "$TRANSCRIPT" 2>/dev/null \
    | grep -o '"name":"Skill","input":{"skill":"[^"]*"' \
    | sed 's/.*"skill":"//; s/"$//' \
    | sort -u | grep -c .)
  [ "$SKILL_COUNT" -gt 0 ] && SKILLS_INFO=" | ${MAGENTA}⚡ ${SKILL_COUNT}${RESET}"
fi

# COST_FMT: notional API cost formatted as e.g. "~$0.42 API". The "~" and
# "API" suffix make it clear this is a hypothetical, not your actual bill.
COST_FMT=$(printf '~$%.2f API' "$COST")

# LIMITS: Max plan 5h and 7d usage with colors and countdowns to their resets.
# Falls back to a "pending" notice before the first API response.
LIMITS=""
if [ -n "$FIVE_H" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  FIVE_H_COLOR=$(pick_color "$FIVE_H_INT")
  LIMITS="${LIMITS} | 5h: ${FIVE_H_COLOR}${FIVE_H_INT}%${RESET}$(fmt_reset "$FIVE_H_RESET")"
fi
if [ -n "$WEEK" ]; then
  WEEK_INT=$(printf '%.0f' "$WEEK")
  WEEK_COLOR=$(pick_color "$WEEK_INT")
  LIMITS="${LIMITS} | 7d: ${WEEK_COLOR}${WEEK_INT}%${RESET}$(fmt_reset "$WEEK_RESET")"
fi
[ -z "$LIMITS" ] && LIMITS=" | ${DIM}plan limits: pending first response${RESET}"

# SUFFIX: small annotations after the model name — reasoning effort and any
# non-default output style.
SUFFIX=""
[ -n "$EFFORT" ]       && SUFFIX="${SUFFIX} ${DIM}(${EFFORT})${RESET}"
[ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ] && SUFFIX="${SUFFIX} ${MAGENTA}[${OUTPUT_STYLE}]${RESET}"

# ─── Output (two lines) ──────────────────────────────────────────────────────
# Line 1: identity + workspace + git state + session diff
echo -e "${CYAN}${BOLD}[${MODEL}]${RESET}${SUFFIX} 📁 ${DIR##*/}${GIT_INFO}${DIFF_INFO}${SKILLS_INFO}"
# Line 2: context bar + Max plan limits + duration + notional API cost
echo -e "${CTX_COLOR}${CTX_BAR}${RESET} ctx ${PCT}%${LIMITS} | ⏱️ ${DURATION} | ${YELLOW}${COST_FMT}${RESET}"

