
DPDK_REV=v18.11
DPDK_BUILD_DIR=$(TOP)/build/dpdk-build
DPDK_DIR=$(DPDK_BUILD_DIR)/rdk_user/dpdk-$(subst v,,$(DPDK_REV))
DPDK_PATCH=$(SNR_DPDK_DIR)/dpdk_diff_snr*.patch

DPDK_TARGET_DIR=/opt/dpdk
RTE_TARGET=x86_64-native-linuxapp-gcc

help:: dpdk.help

dpdk.help:
	$(ECHO) "\n--- dpdk ----"
	$(ECHO) " dpdk-build                	: build dpdk libraries"
	$(ECHO) " dpdk-deploy               	: deploy dpdk libraries on target in $(DPDK_TARGET_DIR)"
	$(ECHO) " dpdk-clean                	: remove $(DPDK_BUILD_DIR) directory"


dpdk-fetch:
	$(Q)if [ ! -f $(SDK_ENV) ]; then \
		echo 'SDK is not installed. Please run the "make sdk-install" command first.'; \
		exit 1; \
	fi;
	$(Q)if [ ! -d $(DPDK_BUILD_DIR) ]; then \
		mkdir -p $(DPDK_DIR) ; \
		cp -r $(SNR_DPDK_DIR)/rdk_user/rdk/* $(DPDK_BUILD_DIR)/rdk_user ; \
		cp -r $(SNR_DPDK_DIR)/rdk_klm/rdk/klm $(DPDK_BUILD_DIR)/rdk_user ; \
		git clone --quiet --single-branch git://dpdk.org/dpdk-stable -b $(DPDK_REV) $(DPDK_DIR) ; \
		cd $(DPDK_DIR) ; \
		cp $(DPDK_PATCH) $(DPDK_DIR)/dpdk_diff_snr.patch ; \
		patch -p1 -s < $(DPDK_DIR)/dpdk_diff_snr.patch ; \
		chmod +x $(DPDK_DIR)/usertools/rdk-setup.sh ; \
	fi;

dpdk-build: dpdk-fetch
	$(Q)if [ -d $(DPDK_BUILD_DIR) ]; then \
		cd $(DPDK_BUILD_DIR)/rdk_user ; \
		source $(SDK_ENV); \
		export CROSS=$$CROSS_COMPILE ; \
		export KSRC=$$SDKTARGETSYSROOT/usr/src/kernel ; \
		export KERNELDIR=$$KSRC ; \
		export SYSROOT=$$SDKTARGETSYSROOT ; \
		source iwa_rdk.env ; \
		export RTE_SDK=$(DPDK_DIR) ; \
		make dpdk ; \
	fi;

dpdk-deploy:
	$(ECHO) "DPDK libraries are installed on $(TARGET) in $(DPDK_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(DPDK_TARGET_DIR)/usertools"
ifeq ($(SNR_RELEASE),)
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/lib $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SCP_CMD) $(DPDK_DIR)/usertools/dpdk-devbind.py $(SSH_TARGET):$(DPDK_TARGET_DIR)/usertools
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/kmod $(SSH_TARGET):$(DPDK_TARGET_DIR)
else
	$(SCP_CMD) -r $(SNR_REL_DIR)/$(SNR_RELEASE)/$(DPDK_TARGET_DIR)/lib $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(DPDK_TARGET_DIR)/usertools/dpdk-devbind.py $(SSH_TARGET):$(DPDK_TARGET_DIR)/usertools
	$(SCP_CMD) -r $(SNR_REL_DIR)/$(SNR_RELEASE)/$(DPDK_TARGET_DIR)/kmod $(SSH_TARGET):$(DPDK_TARGET_DIR)
endif
	$(SSH_CMD) -- "ln -sf $(DPDK_TARGET_DIR)/lib/* /usr/lib"

dpdk-clean:
	$(RM) -r $(DPDK_BUILD_DIR)
