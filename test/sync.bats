#!/usr/bin/env bats
#
# Tests for bin/sync.sh. Each test builds a self-contained throwaway template
# git repo (a minimal copy of this repo's structure with sync.sh copied in) so
# it can control commits, upstream edits, and deletions without touching the
# real repo's history. SYNC points at the copied script, whose REPO_ROOT then
# resolves to the throwaway template.

setup() {
  REAL_SYNC="$BATS_TEST_DIRNAME/../bin/sync.sh"
  TEMPLATE="$BATS_TEST_TMPDIR/template"
  PROJECT="$BATS_TEST_TMPDIR/project"
  SYNC="$TEMPLATE/bin/sync.sh"

  mkdir -p "$TEMPLATE/bin" \
           "$TEMPLATE/.github/ISSUE_TEMPLATE" \
           "$TEMPLATE/docs/templates"

  echo "PR template"            > "$TEMPLATE/.github/pull_request_template.md"
  echo "bug template"          > "$TEMPLATE/.github/ISSUE_TEMPLATE/bug.md"
  echo "glossary v1"           > "$TEMPLATE/docs/glossary.md"
  echo "prd template v1"       > "$TEMPLATE/docs/templates/prd-template.md"
  echo "typescript template"   > "$TEMPLATE/project-claude-template-typescript.md"

  cp "$REAL_SYNC" "$SYNC"
  chmod +x "$SYNC"

  git -C "$TEMPLATE" init -q
  git -C "$TEMPLATE" config user.email test@example.com
  git -C "$TEMPLATE" config user.name "Test"
  git -C "$TEMPLATE" add -A
  git -C "$TEMPLATE" commit -qm "initial template"

  mkdir -p "$PROJECT"
}

# Commit everything currently staged/unstaged in the template repo.
template_commit() {
  git -C "$TEMPLATE" add -A
  git -C "$TEMPLATE" commit -qm "$1"
}

bootstrap() {
  run "$SYNC" init "$PROJECT" --stack=typescript
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------

@test "init requires a --stack flag" {
  run "$SYNC" init "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --stack"* ]]
}

@test "init copies templated files and writes a version stamp" {
  bootstrap
  [ -f "$PROJECT/.github/pull_request_template.md" ]
  [ -f "$PROJECT/.github/ISSUE_TEMPLATE/bug.md" ]
  [ -f "$PROJECT/docs/glossary.md" ]
  [ -f "$PROJECT/docs/templates/prd-template.md" ]
  [ -f "$PROJECT/CLAUDE.md" ]
  [ -f "$PROJECT/.sdlc-template-version" ]

  # CLAUDE.md is the stack template
  run cat "$PROJECT/CLAUDE.md"
  [[ "$output" == *"typescript template"* ]]

  # version stamp records stack + the template HEAD
  run cat "$PROJECT/.sdlc-template-version"
  [[ "$output" == *"stack=typescript"* ]]
  [[ "$output" == *"sha=$(git -C "$TEMPLATE" rev-parse HEAD)"* ]]
}

@test "init refuses to overwrite an already-bootstrapped project without --force" {
  bootstrap
  run "$SYNC" init "$PROJECT" --stack=typescript
  [ "$status" -ne 0 ]
  [[ "$output" == *"use --force"* ]]
}

@test "init does not propagate .github/workflows to the project" {
  mkdir -p "$TEMPLATE/.github/workflows"
  echo "ci" > "$TEMPLATE/.github/workflows/ci.yml"
  template_commit "add template-internal workflow"
  bootstrap
  # workflows are template-internal tooling and must not leak to consumers
  [ ! -e "$PROJECT/.github/workflows" ]
  # but the rest of .github/ is still copied
  [ -f "$PROJECT/.github/ISSUE_TEMPLATE/bug.md" ]
}

@test "init --force re-bootstraps over an existing project" {
  bootstrap
  run "$SYNC" init "$PROJECT" --stack=typescript --force
  [ "$status" -eq 0 ]
}

@test "init never touches consumer-owned docs/prds" {
  bootstrap
  mkdir -p "$PROJECT/docs/prds"
  echo "my prd" > "$PROJECT/docs/prds/keep.md"
  run "$SYNC" init "$PROJECT" --stack=typescript --force
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/docs/prds/keep.md" ]
  run cat "$PROJECT/docs/prds/keep.md"
  [[ "$output" == *"my prd"* ]]
}

# ---------------------------------------------------------------------------
# adopt
# ---------------------------------------------------------------------------

@test "adopt scaffolds an empty project and writes a stamp" {
  run "$SYNC" adopt "$PROJECT" --stack=typescript
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/.github/pull_request_template.md" ]
  [ -f "$PROJECT/docs/glossary.md" ]
  [ -f "$PROJECT/CLAUDE.md" ]
  [ -f "$PROJECT/.sdlc-template-version" ]
  # with no pre-existing CLAUDE.md, adopt creates it from the stack template
  run cat "$PROJECT/CLAUDE.md"
  [[ "$output" == *"typescript template"* ]]
  # a freshly adopted project is in sync
  run "$SYNC" check "$PROJECT"
  [ "$status" -eq 0 ]
}

@test "adopt preserves an existing bespoke CLAUDE.md" {
  echo "bespoke project rules" > "$PROJECT/CLAUDE.md"
  run "$SYNC" adopt "$PROJECT" --stack=typescript
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEPT"* ]]
  run cat "$PROJECT/CLAUDE.md"
  [[ "$output" == *"bespoke project rules"* ]]
  [[ "$output" != *"typescript template"* ]]
  # scaffolding was still added
  [ -f "$PROJECT/docs/glossary.md" ]
}

@test "adopt keeps an existing scaffolding file by default" {
  mkdir -p "$PROJECT/.github"
  echo "my own PR template" > "$PROJECT/.github/pull_request_template.md"
  run "$SYNC" adopt "$PROJECT" --stack=typescript
  [ "$status" -eq 0 ]
  run cat "$PROJECT/.github/pull_request_template.md"
  [[ "$output" == *"my own PR template"* ]]
}

@test "adopt --force overwrites scaffolding but still preserves CLAUDE.md" {
  echo "bespoke project rules" > "$PROJECT/CLAUDE.md"
  mkdir -p "$PROJECT/.github"
  echo "my own PR template" > "$PROJECT/.github/pull_request_template.md"
  run "$SYNC" adopt "$PROJECT" --stack=typescript --force
  [ "$status" -eq 0 ]
  # scaffolding file replaced by the template's
  run cat "$PROJECT/.github/pull_request_template.md"
  [[ "$output" == *"PR template"* ]]
  [[ "$output" != *"my own PR template"* ]]
  # CLAUDE.md is never overwritten, even with --force
  run cat "$PROJECT/CLAUDE.md"
  [[ "$output" == *"bespoke project rules"* ]]
}

@test "adopt refuses to re-stamp an already-adopted project without --force" {
  run "$SYNC" adopt "$PROJECT" --stack=typescript
  [ "$status" -eq 0 ]
  run "$SYNC" adopt "$PROJECT" --stack=typescript
  [ "$status" -ne 0 ]
  [[ "$output" == *"already bootstrapped/adopted"* ]]
}

# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------

@test "check passes cleanly on a freshly bootstrapped project" {
  bootstrap
  run "$SYNC" check "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  [[ "$output" != *"DRIFT"* ]]
}

@test "check flags a non-bootstrapped directory" {
  run "$SYNC" check "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no .sdlc-template-version"* ]]
}

@test "check detects local edits" {
  bootstrap
  echo "edited" >> "$PROJECT/docs/glossary.md"
  run "$SYNC" check "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"local-edits"* ]]
}

@test "check detects upstream changes" {
  bootstrap
  echo "glossary v2" > "$TEMPLATE/docs/glossary.md"
  template_commit "update glossary"
  run "$SYNC" check "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"upstream-newer"* ]]
}

@test "check reports a missing templated file" {
  bootstrap
  rm "$PROJECT/docs/glossary.md"
  run "$SYNC" check "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]
  [[ "$output" == *"glossary.md"* ]]
}

@test "check detects an upstream deletion the project still carries" {
  bootstrap
  git -C "$TEMPLATE" rm -q docs/glossary.md
  template_commit "drop glossary"
  run "$SYNC" check "$PROJECT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REMOVED-UPSTREAM"* ]]
  [[ "$output" == *"glossary.md"* ]]
}

# ---------------------------------------------------------------------------
# update
# ---------------------------------------------------------------------------

@test "update is a no-op when already at template HEAD" {
  bootstrap
  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to update"* ]]
}

@test "update applies upstream changes to an unedited file and advances the stamp" {
  bootstrap
  echo "glossary v2" > "$TEMPLATE/docs/glossary.md"
  template_commit "update glossary"
  local new_head; new_head="$(git -C "$TEMPLATE" rev-parse HEAD)"

  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UPDATED"* ]]

  run cat "$PROJECT/docs/glossary.md"
  [[ "$output" == *"glossary v2"* ]]
  run cat "$PROJECT/.sdlc-template-version"
  [[ "$output" == *"sha=$new_head"* ]]
}

@test "update skips a locally-edited file and warns" {
  bootstrap
  echo "local change" > "$PROJECT/docs/glossary.md"
  echo "glossary v2" > "$TEMPLATE/docs/glossary.md"
  template_commit "update glossary"

  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIPPED"* ]]
  [[ "$output" == *"WARNING"* ]]

  # the local edit is preserved
  run cat "$PROJECT/docs/glossary.md"
  [[ "$output" == *"local change"* ]]
}

@test "update --force overwrites a locally-edited file" {
  bootstrap
  echo "local change" > "$PROJECT/docs/glossary.md"
  echo "glossary v2" > "$TEMPLATE/docs/glossary.md"
  template_commit "update glossary"

  run "$SYNC" update "$PROJECT" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"OVERWRITTEN"* ]]

  run cat "$PROJECT/docs/glossary.md"
  [[ "$output" == *"glossary v2"* ]]
  [[ "$output" != *"local change"* ]]
}

@test "update adds a file newly introduced upstream" {
  bootstrap
  echo "new doc" > "$TEMPLATE/docs/newdoc.md"
  template_commit "add newdoc"

  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADDED"* ]]
  [ -f "$PROJECT/docs/newdoc.md" ]
}

@test "update removes an upstream-deleted unedited file" {
  bootstrap
  git -C "$TEMPLATE" rm -q docs/glossary.md
  template_commit "drop glossary"

  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"REMOVED"* ]]
  [ ! -f "$PROJECT/docs/glossary.md" ]
}

@test "update keeps an upstream-deleted file that has local edits, unless --force" {
  bootstrap
  echo "local change" > "$PROJECT/docs/glossary.md"
  git -C "$TEMPLATE" rm -q docs/glossary.md
  template_commit "drop glossary"

  run "$SYNC" update "$PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEPT"* ]]
  [ -f "$PROJECT/docs/glossary.md" ]

  # re-stamp moved to HEAD, so a second run sees nothing to do for it;
  # force-remove instead
  run "$SYNC" update "$PROJECT" --force
  [ "$status" -eq 0 ]
}
