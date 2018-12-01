include lib.mk/tools.mk

TARGET     ?= ase-sim
TESTSUITE  ?= jenkins

ifeq ($(TARGET),ase-sim)
SSH_PORT   := $(shell grep ^"Host TCP port" build/ase-sim/ase.sim.log 2>/dev/null | grep 22 | cut -d" " -f 4)
SSH_IP     := localhost
endif

ifeq ($(TARGET),vlm_snr1)
SSH_PORT   := 22
SSH_IP     := 128.224.124.124
endif

SSH_TARGET := root@$(SSH_IP)
SSH_OPT    := -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
SSH_CMD    := $(SSH) -p $(SSH_PORT) $(SSH_OPT) $(SSH_TARGET)
SCP_CMD    := $(SCP) -P $(SSH_PORT) $(SSH_OPT)

TARGETTESTBASE	:= $(TOP)/build/targettest/$(TARGET)
TARGETTESTDIR	:= $(TARGETTESTBASE)/$(shell date +%Y%m%d%H%M)

$(TARGETTESTDIR):
	$(eval targettestdir=$(shell basename $(TARGETTESTDIR)))
	$(MKDIR) $(TARGETTESTDIR)
	$(CD) $(TARGETTESTBASE); ln -sfn $(targettestdir) latest

deploy.sshkeys:
	$(SSHPASS) -p root ssh-copy-id $(SSH_TARGET)

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
	$(ECHO) " deploy.sshkeys            : add sshkeys to $(TARGET) from $(TARGET_IP) (not needed for ase-sim)"
	$(ECHO) " testcase.list             : list available testcases"
	$(ECHO) " testcase.%.run            : run testcase %"
	$(ECHO) " testsuite.list            : list available testsuites"
	$(ECHO) " testsuite.run             : run testsuite (default TESTSUITE=$(TESTSUITE))"
	$(ECHO) " testsuite.cleanlog        : remove test logs"

