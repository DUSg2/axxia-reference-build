LABJACK_SAMPLES_BUILD_DIR=$(TOP)/examples/labjack
LABJACK_CONTROL_DIR=$(LABJACK_SAMPLES_BUILD_DIR)/vcn-snr-dio-control
LABJACK_CONTROL=$(LABJACK_CONTROL_DIR)/control
GPIO_CONTROL=/opt/rcs-snr-tests/bin/gpiotest

LABJACK_SAMPLES= vcn-snr-dio-control \
	vcn-snr-test-dio-read \
	vcn-snr-test-setup 

help:: gpio.help

gpio.help:
	$(ECHO) "\n--- gpio-tests ---"
	$(ECHO) " gpio-control-app-build            : build LabJack control app and samples"
	$(ECHO) " gpio-control-app-clean            : build LabJack control app and samples"
	$(ECHO) " gpio-control-labjack-setup        : perform labjack initialization for testing"
	$(ECHO) " gpio-run-tests                    : run gpio tests on target"

gpio-control-app-build:
	for dir in $(LABJACK_SAMPLES); do \
		cd $(LABJACK_SAMPLES_BUILD_DIR)/$$dir ; \
		make ; \
	done;

gpio-control-app-clean:
	for dir in $(LABJACK_SAMPLES); do \
		cd $(LABJACK_SAMPLES_BUILD_DIR)/$$dir ; \
		make -s clean ; \
	done;

gpio-control-labjack-setup: gpio-control-app-build
	$(LABJACK_CONTROL) --setup

gpio-run-tests: gpio-control-labjack-setup
	$(shell FOO_TARGET=$(SSH_TARGET) FOO_PORT=$(SSH_PORT) FOO_CTRL=$(GPIO_CONTROL) FOO_LJC=$(LABJACK_CONTROL) $(LABJACK_CONTROL_DIR)/gpiotest-controller.sh >&2)
