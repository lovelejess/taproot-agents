#!/usr/bin/env bash
#
# install.sh — symlink TapRoot Studios agents into Claude Code's live agent dirs.
#
# This repo is the source of truth. Claude Code only loads agents from
# ~/.claude/agents (global) and <project>/.claude/agents (project-local), so we
# symlink each agent from this repo into the right place. Edits made anywhere
# stay in sync because the live files are just links back here.
#
# Idempotent and safe to re-run (e.g. after `git clone` on a new machine).
# Any pre-existing *real* file at a target path is backed up before we replace
# it with a symlink.
#
# Override the Roamily checkout location if it lives somewhere other than
# ~/roamily-app:
#   ROAMILY_APP_DIR=~/code/roamily-app ./install.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROAMILY_APP_DIR="${ROAMILY_APP_DIR:-$HOME/roamily-app}"

GLOBAL_TARGET="$HOME/.claude/agents"
ROAMILY_TARGET="$ROAMILY_APP_DIR/.claude/agents"
IOS_TARGET="$ROAMILY_APP_DIR/roamily-ios/.claude/agents"

BACKUP_DIR="$REPO_DIR/.install-backups"

linked=0
backed_up=0

link_one() {
  local src="$1" dst="$2"
  # Already the correct symlink? Nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  # A real file (or wrong link) is in the way — preserve it.
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/$(basename "$dst").$(date +%s).bak"
    backed_up=$((backed_up + 1))
  fi
  ln -s "$src" "$dst"
  linked=$((linked + 1))
}

link_dir() {
  local src_dir="$1" dst_dir="$2"
  [ -d "$src_dir" ] || return 0
  mkdir -p "$dst_dir"
  # Only top-level files in src_dir; subdirs (e.g. ios/) are handled separately.
  for f in "$src_dir"/*.md "$src_dir"/*.json; do
    [ -e "$f" ] || continue
    link_one "$f" "$dst_dir/$(basename "$f")"
  done
}

echo "Repo:          $REPO_DIR"
echo "Global target: $GLOBAL_TARGET"
echo "Roamily target:$ROAMILY_TARGET"
echo "iOS target:    $IOS_TARGET"
echo

link_dir "$REPO_DIR/generic"     "$GLOBAL_TARGET"
link_dir "$REPO_DIR/roamily"     "$ROAMILY_TARGET"
link_dir "$REPO_DIR/roamily/ios" "$IOS_TARGET"

echo "Done. $linked symlink(s) created, $backed_up file(s) backed up."
[ "$backed_up" -gt 0 ] && echo "Backups in: $BACKUP_DIR"
exit 0
