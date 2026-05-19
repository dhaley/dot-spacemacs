# magit-ai Makefile

EMACS ?= emacs
EMACS_BATCH = $(EMACS) -Q --batch -L .

SRC_ELS = magit-ai-process.el magit-ai.el magit-ai-sections.el \
          magit-ai-blame.el magit-ai-diff.el magit-ai-log.el
TEST_ELS = test/magit-ai-tests.el
ALL_ELS = $(SRC_ELS) $(TEST_ELS)
ELCS = $(SRC_ELS:.el=.elc)

.PHONY: all compile test clean lint lint-compile lint-checkdoc lint-package \
        lint-relint format format-check coverage coverage-baseline \
        coverage-check benchmark benchmark-baseline benchmark-check

all: compile

## Build

compile: $(ELCS)

%.elc: %.el
	@printf "Compiling $<\n"
	@$(EMACS_BATCH) \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $<

## Test

test:
	@printf "Running tests\n"
	@$(EMACS_BATCH) \
	  -l ert \
	  -l test/magit-ai-tests.el \
	  -f ert-run-tests-batch-and-exit

## Lint

lint: lint-compile lint-checkdoc

lint-compile: compile

lint-checkdoc:
	@printf "Running checkdoc\n"
	@$(EMACS_BATCH) -l scripts/run-checkdoc.el -- $(SRC_ELS)

lint-package:
	@printf "Running package-lint\n"
	@$(EMACS_BATCH) \
	  --eval "(require 'package)" \
	  --eval "(package-initialize)" \
	  -l package-lint \
	  --eval "(setq package-lint-main-file \"magit-ai.el\")" \
	  -f package-lint-batch-and-exit $(SRC_ELS)

lint-relint:
	@printf "Running relint\n"
	@$(EMACS_BATCH) -l relint -f relint-batch $(SRC_ELS)

## Format

format:
	@printf "Formatting source files\n"
	@$(EMACS_BATCH) -l scripts/format.el -- $(ALL_ELS)

format-check:
	@printf "Checking formatting\n"
	@$(EMACS_BATCH) -l scripts/check-format.el -- $(ALL_ELS)

## Coverage

coverage:
	@$(EMACS_BATCH) -l scripts/coverage.el -- run

coverage-baseline:
	@$(EMACS_BATCH) -l scripts/coverage.el -- save

coverage-check:
	@$(EMACS_BATCH) -l scripts/coverage.el -- check

## Benchmark

benchmark:
	@$(EMACS_BATCH) -l scripts/benchmark.el -- run

benchmark-baseline:
	@$(EMACS_BATCH) -l scripts/benchmark.el -- save

benchmark-check:
	@$(EMACS_BATCH) -l scripts/benchmark.el -- check

## Clean

clean:
	@printf "Cleaning\n"
	@rm -f *.elc test/*.elc

# Build order (dependencies)
magit-ai-process.elc:
magit-ai.elc: magit-ai-process.elc
magit-ai-sections.elc: magit-ai-process.elc
magit-ai-blame.elc: magit-ai-process.elc
magit-ai-diff.elc: magit-ai-process.elc
magit-ai-log.elc: magit-ai-process.elc
