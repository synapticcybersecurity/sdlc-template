.PHONY: test

# Run the sync.sh test suite. Requires the bats-core submodule:
#   git submodule update --init
test:
	./test/bats/bin/bats test/
