.PHONY: all coverage clean

TESTS=$(wildcard *.test.sh)
COVERAGE_OUTDIR=kcov.out

all:
	@for i in $(TESTS); do bash "$$i"; done

coverage:
	for i in $(TESTS); do kcov --bash-dont-parse-binary-dir $(COVERAGE_OUTDIR) "$$i"; done

clean:
	rm -rf $(COVERAGE_OUTDIR)
