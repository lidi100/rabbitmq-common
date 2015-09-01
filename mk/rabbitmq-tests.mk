.PHONY: tests-with-broker standalone-tests

ifeq ($(filter rabbitmq-run.mk,$(notdir $(MAKEFILE_LIST))),)
include $(dir $(lastword $(MAKEFILE_LIST)))rabbitmq-run.mk
endif

tests:: tests-with-broker standalone-tests

tests-with-broker:: test-dist
	$(verbose) $(MAKE) start-background-node RABBITMQ_SERVER_START_ARGS='-pa $(CURDIR)/test'
	$(verbose) $(MAKE) start-rabbit-on-node
	$(exec_verbose) echo > $(TEST_TMPDIR)/test-output && \
	if $(foreach SCRIPT,$(WITH_BROKER_SETUP_SCRIPTS),$(SCRIPT) &&) \
	    $(foreach CMD,$(WITH_BROKER_TEST_COMMANDS), \
	     echo >> $(TEST_TMPDIR)/test-output && \
	     echo "$(CMD)." \
               | tee -a $(TEST_TMPDIR)/test-output \
               | $(ERL_CALL) $(ERL_CALL_OPTS) \
               | tee -a $(TEST_TMPDIR)/test-output \
               | egrep '{ok, (ok|passed)}' >/dev/null &&) \
	    MAKE="$(MAKE)" \
	    RABBITMQ_NODENAME="$(RABBITMQ_NODENAME)" \
	      $(foreach SCRIPT,$(WITH_BROKER_TEST_SCRIPTS),$(SCRIPT) &&) : ; \
        then \
	  touch $(TEST_TMPDIR)/.passed ; \
	  printf "\nPASSED\n" ; \
	else \
	  cat $(TEST_TMPDIR)/test-output ; \
	  printf "\n\nFAILED\n" ; \
	fi
	$(verbose) sleep 1
	$(verbose) echo 'rabbit_misc:report_cover(), init:stop().' | $(ERL_CALL) $(ERL_CALL_OPTS) >/dev/null
	$(verbose) sleep 1
	$(verbose) test -f $(TEST_TMPDIR)/.passed

standalone-tests:: test-dist
	$(verbose) $(MAKE) run-broker-deps
	$(exec_verbose) $(if $(STANDALONE_TEST_COMMANDS), \
	  $(foreach CMD,$(STANDALONE_TEST_COMMANDS), \
	    ERL_LIBS="$(CURDIR)/dist:$(DIST_ERL_LIBS)" \
	    $(ERL) $(ERL_OPTS) -pa $(CURDIR)/test -sname standalone_test -eval "init:stop(case $(CMD) of ok -> 0; passed -> 0; _Else -> 1 end)" && \
	  ) \
	:)
	$(verbose) $(if $(STANDALONE_TEST_SCRIPTS),$(foreach SCRIPT,$(STANDALONE_TEST_SCRIPTS),$(SCRIPT) &&) :)