#!/usr/bin/env bash
# compact-check-exclude.sh [--project-root <dir>] <path> [<path>...]
#
# Adds path(s) to <project-root>/.claude/compact-check.json's "exclude"
# list. Excluded files/directories are invisible to the entire compact-check
# hook machinery (scan, baselines, handoffs, queues, messages).
#
# NOTE: .claude/compact-check.json is PROJECT CONFIG -- commit it so
# exclusions are shared with the rest of the team.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: compact-check-exclude.sh [--project-root <dir>] <path> [<path>...]

Adds path(s) to <project-root>/.claude/compact-check.json's "exclude" list.
Project root defaults to $CLAUDE_PROJECT_DIR, then $PWD.

Each <path> must exist and be inside the project root. Directories are
recorded with a trailing slash (matched as a prefix); files are recorded
as exact project-relative paths. The resulting exclude list is deduped
and sorted, then printed.

NOTE: .claude/compact-check.json is project config -- commit it.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=hooks/_compact-check.sh
source "$SCRIPT_DIR/hooks/_compact-check.sh"

PROJECT_ROOT=""
PATHS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        PATHS+=("$1")
        shift
      done
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
fi

if [ "${#PATHS[@]}" -eq 0 ]; then
  echo "error: at least one <path> is required" >&2
  usage >&2
  exit 1
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "error: project root does not exist or is not a directory: $PROJECT_ROOT" >&2
  exit 1
fi
PROJECT_ROOT_ABS=$(cd "$PROJECT_ROOT" && pwd)

REL_ENTRIES=()
for p in "${PATHS[@]}"; do
  if [ ! -e "$p" ]; then
    echo "error: path does not exist: $p" >&2
    exit 1
  fi

  abs=""
  trailing=""
  if [ -d "$p" ]; then
    abs=$(cd "$p" && pwd)
    trailing="/"
  else
    parent_dir=$(cd "$(dirname "$p")" && pwd)
    abs="$parent_dir/$(basename "$p")"
  fi

  case "$abs" in
    "$PROJECT_ROOT_ABS"/*) ;;
    "$PROJECT_ROOT_ABS")
      echo "error: path is the project root itself: $p" >&2
      exit 1
      ;;
    *)
      echo "error: path is outside project root ($PROJECT_ROOT_ABS): $p" >&2
      exit 1
      ;;
  esac

  rel="${abs#"$PROJECT_ROOT_ABS"/}"
  REL_ENTRIES+=("${rel}${trailing}")
done

CLAUDE_DIR="$PROJECT_ROOT_ABS/.claude"
CONFIG_FILE="$CLAUDE_DIR/compact-check.json"
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  printf '%s\n' '{"exclude":[]}' > "$CONFIG_FILE"
fi

NEW_ENTRIES_JSON=$(printf '%s\n' "${REL_ENTRIES[@]}" | jq -R . | jq -s .)

jq --argjson new "$NEW_ENTRIES_JSON" '
  .exclude = (((.exclude // []) + $new) | unique)
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo "Excluded paths for $PROJECT_ROOT_ABS (.claude/compact-check.json -- commit this file):"
jq -r '.exclude[]' "$CONFIG_FILE"

# Many end-user projects gitignore .claude/ wholesale, which would silently
# untrack this file despite the "commit this file" guidance above. Warn
# (informational only -- never touches .gitignore) if git is available and
# reports the config as ignored.
if command -v git >/dev/null 2>&1 \
  && git -C "$PROJECT_ROOT_ABS" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && git -C "$PROJECT_ROOT_ABS" check-ignore -q -- "$CONFIG_FILE" 2>/dev/null; then
  echo "warning: $CONFIG_FILE is gitignored, so it will not be shared with your team. Run \`git add -f .claude/compact-check.json\`, or add a \`!.claude/compact-check.json\` negation to your .gitignore." >&2
fi
