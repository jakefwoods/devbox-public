#!/usr/bin/env bash
# sync.sh — Clone or sync a mutable input to a pinned rev.
#
# Usage:
#   sync.sh <dest> <flake-ref> [<rev>]
#
# If <dest> doesn't exist: clone from <flake-ref>, optionally checkout <rev>.
# If <dest> exists and <rev> given: sync branch to <rev>, preserving local
#   commits and uncommitted changes via rebase.
# If <dest> exists and no <rev>: nothing to do.
#
# Errors if the pinned rev isn't on the same lineage, or if local changes
# conflict with the rebase.

set -euo pipefail

GIT="@git@"
NIX="@nix@"

# `nix flake clone` shells out to `git` from PATH, but the home-manager
# activation environment has a minimal PATH without git. Put our pinned git
# on PATH so nix's internal invocations resolve.
export PATH="$(dirname "$GIT"):$PATH"

# The home-manager activation environment has no git identity configured, so
# `git commit` and `git rebase` below would fail with "Author identity unknown".
# The temp commit and rebase are ephemeral (unwound via reset), so the identity
# is never persisted — a placeholder is sufficient.
export GIT_AUTHOR_NAME="mutableInputs" GIT_AUTHOR_EMAIL="mutableInputs@localhost"
export GIT_COMMITTER_NAME="mutableInputs" GIT_COMMITTER_EMAIL="mutableInputs@localhost"

dest="${1:?Usage: sync.sh <dest> <flake-ref> [<rev>]}"
flake_ref="${2:?Usage: sync.sh <dest> <flake-ref> [<rev>]}"
rev="${3:-}"
name="$(basename "$dest")"

if [ ! -d "$dest" ]; then
  # --- Fresh clone ---
  echo "mutableInputs: cloning $name..."
  "$NIX" flake clone "$flake_ref" --dest "$dest"

  if [ -n "$rev" ]; then
    "$GIT" -C "$dest" checkout -B main "$rev"
  fi
else
  # --- Existing repo ---
  if [ -z "$rev" ]; then
    # No pinned rev — nothing to sync.
    exit 0
  fi

  # Check if we're already at or ahead of the pinned rev.
  if "$GIT" -C "$dest" merge-base --is-ancestor "$rev" HEAD 2>/dev/null; then
    # HEAD is at or ahead of rev — nothing to do.
    exit 0
  fi

  echo "mutableInputs: syncing $name to $rev..."
  "$GIT" -C "$dest" fetch origin

  # Lineage check: pinned rev must be an ancestor of HEAD (ahead — fine) or
  # HEAD must be an ancestor of rev (behind — we rebase).
  if ! "$GIT" -C "$dest" merge-base --is-ancestor HEAD "$rev" 2>/dev/null; then
    echo "mutableInputs: ERROR: $name has diverged from pinned rev $rev."
    echo "The pinned rev is not on the current branch's lineage."
    echo "Reconcile manually (rebase or reset) and re-run home-manager switch."
    exit 1
  fi

  # HEAD is strictly behind rev. Rebase any local commits onto the pinned rev.

  # Temp-commit any local changes so rebase handles everything uniformly.
  had_changes=false
  if ! "$GIT" -C "$dest" diff --quiet 2>/dev/null || \
     ! "$GIT" -C "$dest" diff --cached --quiet 2>/dev/null || \
     [ -n "$("$GIT" -C "$dest" ls-files --others --exclude-standard)" ]; then
    "$GIT" -C "$dest" add -A
    "$GIT" -C "$dest" commit --no-verify -m "TEMP: mutableInputs local changes"
    had_changes=true
  fi

  # Rebase local commits onto the pinned rev.
  if ! "$GIT" -C "$dest" rebase --onto "$rev" "$rev" 2>/dev/null; then
    "$GIT" -C "$dest" rebase --abort
    if $had_changes; then
      "$GIT" -C "$dest" reset --mixed HEAD~1
    fi
    echo "mutableInputs: ERROR: $name cannot be cleanly updated to pinned rev $rev."
    echo "Local changes conflict with the update. Reconcile manually."
    exit 1
  fi

  # Undo the temp commit, restoring changes to the working tree.
  if $had_changes; then
    "$GIT" -C "$dest" reset --mixed HEAD~1
  fi
fi
