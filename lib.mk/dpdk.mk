
BRANCH=18.05
SRCREV = "a5dce55556286cc56655320d975c67b0dbe08693"
DPDK_BUILD_DIR=$(TOP)/build/dpdk-build
DPDK_DIR=$(DPDK_BUILD_DIR)/rdk_user/dpdk-$(BRANCH)
DPDK_PATCH=$(SNR_DPDK_DIR)/dpdk_diff_snr*.patch

DPDK_TARGET_DIR=/opt/dpdk
RTE_TARGET=x86_64-native-linuxapp-gcc

help:: dpdk.help

dpdk.help:
	$(ECHO) "\n--- dpdk ----"
	$(ECHO) " dpdk-build                : build dpdk libraries"
	$(ECHO) " dpdk-deploy               : deploy dpdk libraries on target in $(DPDK_TARGET_DIR)"
	$(ECHO) " dpdk-clean                : remove $(DPDK_BUILD_DIR) directory"


dpdk-fetch:
	$(Q)if [ ! -f $(SDK_ENV) ]; then \
		echo 'SDK is not installed. Please run the "make sdk-install" command first.'; \
		exit 1; \
	fi;
	$(Q)if [ ! -d $(DPDK_BUILD_DIR) ]; then \
		mkdir -p $(DPDK_DIR) ; \
		cp -r $(SNR_DPDK_DIR)/rdk_user $(DPDK_BUILD_DIR) ; \
		git clone --single-branch git://dpdk.org/dpdk-stable -b $(BRANCH) $(DPDK_DIR) ; \
		cd $(DPDK_DIR) ; \
		git checkout $(SRCREV) ; \
		cp $(DPDK_PATCH) $(DPDK_DIR)/dpdk_diff_snr.patch ; \
		patch -p1 -s < $(DPDK_DIR)/dpdk_diff_snr.patch ; \
	fi;

dpdk-build: dpdk-fetch
	$(Q)if [ -d $(DPDK_BUILD_DIR) ]; then \
		cd $(DPDK_BUILD_DIR)/rdk_user ; \
		source $(SDK_ENV); \
		export CROSS=$$CROSS_COMPILE ; \
		export QAT_DRV_SRC=$$SDKTARGETSYSROOT/usr/src/kernel/drivers/staging/intel/qat ; \
		export KSRC=$$SDKTARGETSYSROOT/usr/src/kernel ; \
		export KERNELDIR=$$KSRC ; \
		export IES_API_DIR=$(DPDK_BUILD_DIR)/rdk_user/user_modules/ies-api ; \
		export PATH=$(DPDK_BUILD_DIR)/rdk_user/user_modules/ies-api/core:$$PATH ; \
		export SYSROOT=$$SDKTARGETSYSROOT ; \
		export RTE_SDK=$(DPDK_DIR) ; \
		export LIB_QAT18_DIR=$(DPDK_BUILD_DIR)/rdk_user/user_modules/qat ; \
		chmod +x $(DPDK_DIR)/usertools/rdk-setup.sh ; \
		make dpdk ; \
	fi;

dpdk-deploy:
	$(ECHO) "DPDK libraries are installed on $(TARGET) in $(DPDK_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(DPDK_TARGET_DIR)/usertools"
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/lib $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SCP_CMD) $(DPDK_DIR)/usertools/dpdk-devbind.py $(SSH_TARGET):$(DPDK_TARGET_DIR)/usertools
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/kmod $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SSH_CMD) -- "ln -sf $(DPDK_TARGET_DIR)/lib/* /usr/lib64"

dpdk-clean:
	$(RM) -r $(DPDK_BUILD_DIR)
