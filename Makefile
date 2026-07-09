.PHONY: test lint

# Run the bats test suites. Requires the bats-core submodule:
#   git submodule update --init
test:
	./test/bats/bin/bats test/

# Static-analysis the shell scripts with shellcheck (-x follows sourced files).
# bin/cw and hooks/git/pre-commit have no .sh extension, so they're listed
# explicitly alongside the globs.
lint:
	shellcheck -x bin/sync.sh bin/cw hooks/git/pre-commit \
		hooks/pre-bash.sh hooks/pre-edit.sh hooks/guards/*.sh hooks/lib/*.sh
