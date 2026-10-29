#!/usr/bin/env bash
# CLOUD / LINUX SETUP — install the pinned engine and build the import cache.
#
# WHY THIS EXISTS
# Development moved off the owner's Windows machine (2026-10-16) to Claude Code cloud sessions and
# a Linux desktop. Neither has the engine CLAUDE.md points at. This installs the SAME build CI
# uses — the pin (tag, archive, digest, --version string) is copied from
# .github/actions/setup-godot/action.yml, and if the two ever disagree that file is the truth.
#
# Usage, from the repository root:   bash tools/cloud_setup.sh
# Then the ladder in CLAUDE.md runs with G=godot. Linux has no separate _console binary.
#
# It is idempotent: an already-installed pinned build is kept, and --import always runs, because a
# fresh clone has no .godot/ cache and every class_name reference fails to parse without it.
#
# MUST NOT: install a mono/.NET build, or any engine whose --version differs from the pin.
set -euo pipefail

TAG="4.7.2-stable"
ARCHIVE="Godot_v4.7.2-stable_linux.x86_64.zip"
BINARY="Godot_v4.7.2-stable_linux.x86_64"
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
VERSION="4.7.2.stable.official.ed1daf0bf"

if [ -w /usr/local/bin ]; then BIN_DIR=/usr/local/bin; else BIN_DIR="$HOME/.local/bin"; fi
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if command -v godot >/dev/null 2>&1 && [ "$(godot --version 2>/dev/null | tail -n 1)" = "$VERSION" ]; then
	echo "godot $VERSION already installed at $(command -v godot)"
else
	work="$(mktemp -d)"
	curl -fsSL --retry 3 --retry-delay 5 -o "$work/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/$TAG/$ARCHIVE"
	echo "$SHA512  $work/godot.zip" | sha512sum -c -
	unzip -o -q "$work/godot.zip" -d "$work"
	install -m 0755 "$work/$BINARY" "$BIN_DIR/godot"
	rm -rf "$work"
	godot --version | tail -n 1 | grep -Fxq "$VERSION"
	echo "installed godot $VERSION at $BIN_DIR/godot"
fi

godot --headless --import > import.log 2>&1 || true
if grep -nE 'SCRIPT ERROR|Parse Error' import.log; then
	echo "import failed: a script did not compile (see import.log)" >&2
	exit 1
fi
echo "import cache built. Next: godot --headless res://tests/test_runner.tscn --quit-after 400"
