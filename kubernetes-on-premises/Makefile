SHELL := /bin/sh

.PHONY: help check ch01 ch02 ch04 ch07 appendix-d vendor-refresh clean

help:   ## List every target
	@grep -hE '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) \
	  | sed -e 's/:.*##/\t/' | sort

check:  ## Run every chapter's self-test
	@$(MAKE) --no-print-directory ch01
	@$(MAKE) --no-print-directory ch02
	@$(MAKE) --no-print-directory ch04
	@$(MAKE) --no-print-directory ch07
	@./tools/appendix-d.py --check
	@echo "all checks OK"

ch01:   ## Chapter 1 - the dependency inventory finds twelve rows
	@cd chapters/ch01 && ./inventory.sh workload > /tmp/inv.$$$$.csv && \
	  n=$$(awk 'NR>1' /tmp/inv.$$$$.csv | wc -l | tr -d ' ') && \
	  rm -f /tmp/inv.$$$$.csv && \
	  [ "$$n" = "12" ] && echo "ch01 OK  ($$n dependencies)" || \
	  { echo "ch01 FAIL: expected 12 rows, got $$n"; exit 1; }

ch02:   ## Chapter 2 - the obligations template parses
	@awk -F, 'NR==1 && $$0 != "obligation,control,artifact,chapter" \
	  { print "ch02 FAIL: header changed"; exit 1 } \
	  END { print "ch02 OK  (" NR-1 " obligations)" }' \
	  chapters/ch02/obligations.csv

ch04:   ## Chapter 4 - exactly four products ship a BSI profile
	@n=$$(cd chapters/ch04 && ./profiles.sh has bsi | wc -l | tr -d ' '); \
	 t=$$(cd chapters/ch04 && ./profiles.sh products | wc -l | tr -d ' '); \
	 [ "$$n" = "4" ] && echo "ch04 OK  ($$n of $$t products ship bsi)" || \
	 { echo "ch04 FAIL: expected 4 bsi products, got $$n"; exit 1; }

ch07:   ## Chapter 7 - the exception register keeps its shape
	@h=$$(head -1 chapters/ch07/exceptions.csv); \
	 e="rule,profile,kind,why,compensating_control,owner,decided,review"; \
	 [ "$$h" = "$$e" ] && echo "ch07 OK  (exception register schema)" || \
	 { echo "ch07 FAIL: exceptions.csv header changed"; exit 1; }

appendix-d:  ## Regenerate the Appendix D tables from the control files
	@./tools/appendix-d.py

coverage:  ## How much of the compendium has evidence behind it
	@./tools/coverage.py

pending:  ## Which requirements are still owed, by chapter
	@./tools/coverage.py --pending

vendor-refresh:  ## Re-download the control files. Needs a network.
	@b=https://raw.githubusercontent.com/ComplianceAsCode/content/master/controls; \
	 for f in bsi_app_4_4.yml bsi_sys_1_6.yml; do \
	   curl -sSf "$$b/$$f" -o vendor/compliance-as-code/$$f || exit 1; \
	 done; \
	 ./tools/appendix-d.py --check

clean:  ## Remove generated evidence
	rm -rf evidence/ch* evidence/REGISTER.csv
