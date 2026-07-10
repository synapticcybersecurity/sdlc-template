.PHONY: test lint install-git-hooks

# Run the bats test suites. Requires the bats-core submodule:
#   git submodule update --init
test:
	./test/bats/bin/bats test/

# Wire the git-native pre-commit into THIS repo so a manual `git commit` of a
# secret is blocked too. Absolute path so linked worktrees inherit it. For other
# repos: git -C <repo> config core.hooksPath <abs>/hooks/git (or --global).
install-git-hooks:
	git config core.hooksPath "$(shell git rev-parse --show-toplevel)/hooks/git"
	@echo "core.hooksPath -> $$(git config core.hooksPath)"

# Static-analysis the shell scripts with shellcheck (-x follows sourced files).
# bin/cw and hooks/git/pre-commit have no .sh extension, so they're listed
# explicitly alongside the globs.
lint:
	shellcheck -x bin/sync.sh bin/cw hooks/git/pre-commit \
		hooks/pre-bash.sh hooks/pre-edit.sh hooks/guards/*.sh hooks/lib/*.sh
