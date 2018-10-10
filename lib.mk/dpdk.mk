
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
	$(ECHO) " dpdk-build                : builds dpdk"
	$(ECHO) " dpdk-build-all            : builds dpdk with examples and tests"
	$(ECHO) " dpdk-deploy               : deploys dpdk libraries on target in $(DPDK_TARGET_DIR)"
	$(ECHO) " dpdk-deploy-all           : deploys dpdk libraries with examples and tests on target in $(DPDK_TARGET_DIR)"
	$(ECHO) " dpdk-clean                : deletes $(DPDK_DIR) directory"

dpdk-fetch:
	$(Q)if [ ! -f $(SDK_ENV) ]; then \
		echo 'SDK is not installed. Run first "make install-sdk" command.'; \
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
	fi

dpdk-build-examples:
	$(CD) $(DPDK_DIR)/examples; \
	source $(SDK_ENV); \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib64 ; \
	export IES_API_DIR=$$SDKTARGETSYSROOT/usr ; \
	export LIB_QAT18_DIR=$$SDKTARGETSYSROOT/usr ; \
	export RTE_SDK=$(DPDK_DIR) ; \
	export RTE_TARGET=$(RTE_TARGET) ; \
	export RTE_DEVEL_BUILD="n" ;\
	make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS";
	$(RM) -r $(DPDK_DIR)/$(RTE_TARGET)/examples;
	$(MKDIR) $(DPDK_DIR)/$(RTE_TARGET)/examples; 
	$(FIND) $(DPDK_DIR)/examples -type f -executable -exec cp {} $(DPDK_DIR)/$(RTE_TARGET)/examples \;
	$(FIND) $(DPDK_DIR)/examples -iname *.map -exec cp {} $(DPDK_DIR)/$(RTE_TARGET)/examples \;
	$(FIND) $(DPDK_DIR)/examples -iname *.so -exec cp {} $(DPDK_DIR)/$(RTE_TARGET)/examples \;

dpdk-build-tests:
	$(CD) $(DPDK_DIR)/test; \
	source $(SDK_ENV); \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib64 ; \
	export IES_API_DIR=$$SDKTARGETSYSROOT/usr ; \
	export LIB_QAT18_DIR=$$SDKTARGETSYSROOT/usr; \
	export RTE_SDK=$(DPDK_DIR); \
	export RTE_TARGET=$(RTE_TARGET); \
	export RTE_DEVEL_BUILD="n" ;\
	make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS" RTE_SRCDIR=$(DPDK_DIR)/test ;
	$(RM) -r $(DPDK_DIR)/$(RTE_TARGET)/tests;
	$(MKDIR) $(DPDK_DIR)/$(RTE_TARGET)/tests;
	$(CP) $(DPDK_DIR)/test/build/app/* $(DPDK_DIR)/$(RTE_TARGET)/tests;

dpdk-deploy:
	$(ECHO) "DPDK libraries are installed on $(TARGET) in $(DPDK_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(DPDK_TARGET_DIR)"
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/lib $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SSH_CMD) -- "ln -sf $(DPDK_TARGET_DIR)/lib/* /usr/lib64"
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/app $(SSH_TARGET):$(DPDK_TARGET_DIR)
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/kmod $(SSH_TARGET):$(DPDK_TARGET_DIR)

dpdk-deploy-examples:
	$(ECHO) "DPDK examples are installed on $(TARGET) in $(DPDK_TARGET_DIR) directory."
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/examples $(SSH_TARGET):$(DPDK_TARGET_DIR);

dpdk-deploy-tests:
	$(ECHO) "DPDK tests are installed on $(TARGET) in $(DPDK_TARGET_DIR) directory."
	$(SCP_CMD) -r $(DPDK_DIR)/$(RTE_TARGET)/tests $(SSH_TARGET):$(DPDK_TARGET_DIR);

dpdk-deploy-all: dpdk-deploy dpdk-deploy-examples dpdk-deploy-tests

dpdk-clean:
	$(RM) -r $(DPDK_BUILD_DIR)
