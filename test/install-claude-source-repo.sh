#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

mkdir -p "$TEST_TMPDIR/bin" "$TEST_TMPDIR/home"

cat > "$TEST_TMPDIR/bin/git" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GIT_LOG"
case "$*" in
  *rev-parse*|*show-ref*|*"remote -v"*) exec /usr/bin/git "$@" ;;
  *ls-remote*) echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/local/workflow-hardening" ;;
esac
exit 0
STUB

cat > "$TEST_TMPDIR/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPX_LOG"
exit 0
STUB

chmod +x "$TEST_TMPDIR/bin/git" "$TEST_TMPDIR/bin/npx"
: > "$TEST_TMPDIR/git.log"
: > "$TEST_TMPDIR/npx.log"

OUTPUT="$(HOME="$TEST_TMPDIR/home" \
PATH="$TEST_TMPDIR/bin:$PATH" \
GIT_LOG="$TEST_TMPDIR/git.log" \
NPX_LOG="$TEST_TMPDIR/npx.log" \
  "$REPO_ROOT/install-claude.sh" \
    --skills-only \
    --no-claude-code \
    --agent codex \
    --no-external \
    --no-impeccable \
    --source-repo corioliskraft/.dotfiles \
    --version aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)"

if ! grep -q 'https://github.com/corioliskraft/.dotfiles.git' "$TEST_TMPDIR/git.log"; then
  echo "FAIL: installer did not fetch first-party skills from the selected fork"
  exit 1
fi

fetch_dir="$(awk '$3 == "remote" && $4 == "add" && $5 == "origin" && $6 == "https://github.com/corioliskraft/.dotfiles.git" { print $2; exit }' "$TEST_TMPDIR/git.log")"
if [[ -z "$fetch_dir" ]]; then
  echo "FAIL: installer did not create a checkout for the selected fork"
  exit 1
fi

if ! grep -Fq -- "-C $fetch_dir fetch --quiet --depth 1 origin aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$TEST_TMPDIR/git.log"; then
  echo "FAIL: installer did not fetch the requested revision from the selected fork checkout"
  exit 1
fi

if ! grep -Fq -- "add $fetch_dir -g" "$TEST_TMPDIR/npx.log"; then
  echo "FAIL: Skills CLI did not install from the selected fork checkout"
  exit 1
fi

if ! printf '%s\n' "$OUTPUT" | grep -Fq 'corioliskraft/.dotfiles — auto-discovered patterns'; then
  echo "FAIL: installation summary did not report the selected fork"
  exit 1
fi

echo "PASS: installer can pin first-party skills to an explicit fork"
