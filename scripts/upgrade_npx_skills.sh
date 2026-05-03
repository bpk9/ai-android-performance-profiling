#!/usr/bin/env bash
# Pull the latest versions of skills installed via the Skills CLI (`npx skills`).
# Docs: https://skills.sh/ — update command refreshes from each skill's source repo.
#
# Usage:
#   ./scripts/upgrade_npx_skills.sh              # project + global (default)
#   ./scripts/upgrade_npx_skills.sh project     # project-scoped install (e.g. .agents/skills)
#   ./scripts/upgrade_npx_skills.sh global      # ~/.cursor/skills (or user agent dirs)
#   ./scripts/upgrade_npx_skills.sh all         # same as no args
#
# Env:
#   SKILLS_NPX_FLAGS  optional extra args between npx and "skills" (e.g. "--yes" for non-interactive npx)
#
# Requires Node.js 18+ and network access.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found; install Node.js (18+) so npx is on PATH" >&2
  exit 1
fi

# Optional: reject ancient Node (Skills CLI expects 18+)
if command -v node >/dev/null 2>&1; then
  _major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  if [[ "${_major}" -lt 18 ]]; then
    echo "error: Node 18+ required for npx skills (found major version ${_major})" >&2
    exit 1
  fi
fi

run_skills() {
  if [[ -n "${SKILLS_NPX_FLAGS:-}" ]]; then
    # shellcheck disable=SC2086
    npx ${SKILLS_NPX_FLAGS} skills "$@"
  else
    npx skills "$@"
  fi
}

scope="${1:-all}"
case "$scope" in
  all)
    echo "Upgrading project skills (this repo)..."
    run_skills update -p -y
    echo
    echo "Upgrading global skills (user)..."
    run_skills update -g -y
    ;;
  project|p)
    run_skills update -p -y
    ;;
  global|g)
    run_skills update -g -y
    ;;
  auto|a)
    # One command: non-interactive default (project if in a project, else global)
    run_skills update -y
    ;;
  -h|--help|help)
    cat <<'EOF'
Upgrade skills installed with "npx skills" (https://skills.sh).

Usage: upgrade_npx_skills.sh [all|project|global|auto]

  all       Update project install then global (user) — default
  project   Project skills only (-p)
  global    Global/user skills only (-g)
  auto      Single run: npx skills update -y (CLI picks project vs global)

Env: SKILLS_NPX_FLAGS — optional extra flags between npx and "skills"
EOF
    exit 0
    ;;
  *)
    echo "error: unknown scope '$scope' (use: all, project, global, auto, or --help)" >&2
    exit 1
    ;;
esac

echo
echo "Done. Restart the editor if it caches skill files."
