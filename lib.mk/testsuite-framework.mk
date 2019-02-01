TESTSUITE  ?= jenkins

TARGETTESTBASE	:= $(TOP)/build/targettest/$(TARGET)
TARGETTESTDIR	:= $(TARGETTESTBASE)/$(shell date +%Y%m%d%H%M)

$(TARGETTESTDIR):
	$(eval targettestdir=$(shell basename $(TARGETTESTDIR)))
	$(MKDIR) $(TARGETTESTDIR)
	$(CD) $(TARGETTESTBASE); ln -sfn $(targettestdir) latest

testcase.list:
	$(SSH_CMD) -- "/opt/rcs-snr-tests/bin/rcs-snr-tests -l" | sed 's/^/testcase./' | sed 's/$$/.run/'

testcase.%.run: $(TARGETTESTDIR)
	$(eval targettestlog=$(TARGETTESTDIR)/$*.log)
	$(ECHO) ' Log @ $(targettestlog)'
	$(SSH_CMD) -- "/opt/rcs-snr-tests/bin/rcs-snr-tests -v -d $*" &> $(targettestlog); \
		if [ $$? = 0 ]; then \
			grep "Command ended with" $(targettestlog); \
			echo -e " Test $@ OK\n" ; \
		else \
			echo -e " Test $@ FAILED\n" ; \
			cat $(targettestlog); \
			exit -1; \
		fi

testsuite.list:
	$(SSH_CMD) -- "/opt/rcs-snr-tests/bin/rcs-snr-tests -t"

testsuite.run: $(TARGETTESTDIR)
	$(eval targettestlog=$(TARGETTESTDIR)/testsuite_$(TESTSUITE).log)
	$(ECHO) ' Log @ $(targettestlog)'
	$(SSH_CMD) -- "/opt/rcs-snr-tests/bin/rcs-snr-tests -v -d -s $(TESTSUITE)" &> $(targettestlog); \
		if [ $$? = 0 ]; then \
			grep "Command ended with" $(targettestlog); \
			echo -e " Test $@ OK\n" ; \
		else \
			echo -e " Test $@ FAILED\n" ; \
			cat $(targettestlog); \
			exit -1; \
		fi

testsuite.cleanlog:
	$(RM) -r $(TARGETTESTBASE)

help:: testsuite-framework.help

testsuite-framework.help:
	$(ECHO) "\n--- testsuite-framework ---"
	$(ECHO) " deploy.sshkeys            	: add sshkeys to $(TARGET) from $(TARGET_IP) (not needed for ase-sim)"
	$(ECHO) " testcase.list             	: list available testcases"
	$(ECHO) " testcase.%.run            	: run testcase %"
	$(ECHO) " testsuite.list            	: list available testsuites"
	$(ECHO) " testsuite.run             	: run testsuite (default TESTSUITE=$(TESTSUITE))"
	$(ECHO) " testsuite.cleanlog        	: remove test logs"

