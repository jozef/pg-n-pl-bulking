.PHONY: all clean test

all:
	prove -l t/01_test-clean-db.t && make test

test:
	prove -l t/

clean:
	rm -rf tmp/*.tsv tmp/*.tsv_from-last-test
