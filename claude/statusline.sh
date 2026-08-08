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

# MODEL: human-readable name of the model in use this session (e.g. "Opus",
# "Sonnet 4.6"). Comes from .model.display_name.
MODEL=$(echo "$input" | jq -r '.model.display_name')

# DIR: absolute path of the current working directory. We only display the
# basename later (${DIR##*/}) to keep the line short.
DIR=$(echo "$input" | jq -r '.workspace.current_dir')

# PCT: percentage of the CONVERSATION context window used (0–100). This is
# tokens-in-this-chat vs. the model's max context (e.g. 200K). It is NOT the
# Max plan quota — that's $FIVE_H / $WEEK below. Truncated to int with cut.
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# DURATION_MS: wall-clock time since the session started, in milliseconds.
# Includes idle time (you thinking), not just API time.
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# COST: notional API cost in USD that this session WOULD HAVE COST on
# pay-per-token API billing. On a Max/Pro plan you don't actually pay this —
# it's shown as a reference for "what API usage am I burning equivalent to".
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# LINES_ADDED / LINES_REMOVED: cumulative lines of code Claude has added or
# removed via Edit/Write tools during this session. Useful for a quick "what
# did this session actually do" diff summary.
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# EFFORT: current reasoning effort level (low / medium / high / xhigh / max).
# Reflects live `/effort` changes mid-session. Absent for models that don't
# support reasoning effort, in which case we just don't show it.
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

# OUTPUT_STYLE: name of the active output style. We only display it when it's
# something other than "default" to avoid clutter.
OUTPUT_STYLE=$(echo "$input" | jq -r '.output_style.name // empty')

# FIVE_H: percentage (0–100) of the Max plan's 5-hour rolling window used.
# This is the SAME number you see at claude.ai/settings/usage. The 5h window
# is rolling — it resets 5h after your first message in the window, not on
# wall-clock boundaries. Absent until the first API response in the session.
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# WEEK: percentage (0–100) of the Max plan's 7-day rolling window used. Also
# matches claude.ai/settings/usage. Same caveat: absent until first response.
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# FIVE_H_RESET / WEEK_RESET: Unix epoch seconds when each window resets. Used
# by fmt_reset() further down to render a compact countdown next to each
# percentage (e.g. "5h: 23% (0 in 2h 14m)").
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_RESET=$(echo "$input"   | jq -r '.rate_limits.seven_day.resets_at // empty')

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

# MINS / SECS: session wall-clock duration broken into m and s.
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# DIFF_INFO: "+lines/-lines" summary, only shown if anything changed.
DIFF_INFO=""
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
  DIFF_INFO=" | ${GREEN}+${LINES_ADDED}${RESET}/${RED}-${LINES_REMOVED}${RESET}"
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
echo -e "${CYAN}${BOLD}[${MODEL}]${RESET}${SUFFIX} 📁 ${DIR##*/}${GIT_INFO}${DIFF_INFO}"
# Line 2: context bar + Max plan limits + duration + notional API cost
echo -e "${CTX_COLOR}${CTX_BAR}${RESET} ctx ${PCT}%${LIMITS} | ⏱️ ${MINS}m${SECS}s | ${YELLOW}${COST_FMT}${RESET}"

