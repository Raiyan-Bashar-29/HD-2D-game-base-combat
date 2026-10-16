#!/usr/bin/env bash
# SESSION START — every Claude Code cloud session gets the pinned engine and a built import cache.
#
# WHY THIS EXISTS
# A cloud container starts from a fresh clone: no godot on PATH and no .godot/ cache, so the ladder
# in CLAUDE.md cannot run. tools/cloud_setup.sh fixes both; this hook runs it before the first turn
# so no session has to remember to. It also exports G=godot, the name the ladder uses.
#
# MUST NOT: run outside a cloud session (a local Linux machine runs cloud_setup.sh by hand), or
# duplicate the install logic — the pin lives in cloud_setup.sh and setup-godot/action.yml only.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

cd "$CLAUDE_PROJECT_DIR"
bash tools/cloud_setup.sh

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
	echo 'export G=godot' >> "$CLAUDE_ENV_FILE"
fi
