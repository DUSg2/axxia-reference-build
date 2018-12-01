SAMPLES_TARGET_DIR=/opt/rdk-samples
SAMPLES_BUILD_DIR=$(TOP)/build/rdk-samples
RTE_TARGET=x86_64-native-linuxapp-gcc
DPDK_DIR=$(TOP)/build/dpdk-build/rdk_user/dpdk-$(BRANCH)

RDK_SAMPLES=crypto_inline \
	    crypto_lookaside \
	    data_path_sample_multiFlow \
	    PortSetMode

help:: rdk-samples.help

rdk-samples.help:
	$(ECHO) "\n--- rdk-samples ---"
	$(ECHO) " rdk-samples-list          : print a list of available rdk-samples"
	$(ECHO) " rdk-samples-build         : build all rdk-samples"
	$(ECHO) " rdk-samples-deploy        : deploy rdk-samples on target in $(SAMPLES_TARGET_DIR) directory"
	$(ECHO) " rdk-samples-clean         : remove $(SAMPLES_BUILD_DIR) directory"

rdk-samples-list:
	$(ECHO) List of rdk-samples to build is: $(RDK_SAMPLES)

rdk-samples-fetch:
	$(Q)if [ ! -d $(DPDK_DIR) ]; then \
		echo 'DPDK libraries are not built. Please run "make dpdk-build" command first.'; \
		exit 1; \
	fi;
	$(Q)if [ ! -d $(SAMPLES_BUILD_DIR) ]; then \
		mkdir $(SAMPLES_BUILD_DIR) ; \
		for dir in $(RDK_SAMPLES); do \
			cp -r $(AXXIA_RDK_SAMPLES)/$$dir $(SAMPLES_BUILD_DIR); \
		done; \
	fi;

rdk-samples-build: rdk-samples-fetch
	$(Q)source $(SDK_ENV) ; \
	export CROSS=$$CROSS_COMPILE ; \
	export QAT_DRV_SRC=$$SDKTARGETSYSROOT/usr/src/kernel/drivers/staging/intel/qat ; \
	export KSRC=$$SDKTARGETSYSROOT/usr/src/kernel ; \
	export KERNELDIR=$$KSRC ; \
	export IES_API_DIR=$(DPDK_BUILD_DIR)/rdk_user/user_modules/ies-api ; \
	export PATH=$(DPDK_BUILD_DIR)/rdk_user/user_modules/ies-api/core:$$PATH ; \
	export SYSROOT=$$SDKTARGETSYSROOT ; \
	export RTE_SDK=$(DPDK_DIR) ; \
	export LIB_QAT18_DIR=$(DPDK_BUILD_DIR)/rdk_user/user_modules/qat ; \
	export HLP_LIBDIR=$$SDKTARGETSYSROOT/usr/lib64 ; \
	for dir in $(RDK_SAMPLES); do \
		cd $(SAMPLES_BUILD_DIR)/$$dir ; \
		make -s clean ; \
		make LIBRARY="-L$$HLP_LIBDIR -lies_sdk -lpthread" ; \
	done;

rdk-samples-install:
	$(Q)if [ ! -d $(SAMPLES_BUILD_DIR)/build ]; then \
		mkdir -p $(SAMPLES_BUILD_DIR)/build; \
		cp $(SAMPLES_BUILD_DIR)/crypto_inline/build/snr_test $(SAMPLES_BUILD_DIR)/build/crypto_inline; \
		cp $(SAMPLES_BUILD_DIR)/crypto_lookaside/build/snr_test $(SAMPLES_BUILD_DIR)/build/crypto_lookaside; \
		cp $(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow/build/snr_test  $(SAMPLES_BUILD_DIR)/build/data_path_sample_multiFlow; \
		cp $(SAMPLES_BUILD_DIR)/PortSetMode/snrPortSetMode $(SAMPLES_BUILD_DIR)/build/snrPortSetMode ; \
	fi;

rdk-samples-deploy: rdk-samples-install
	$(ECHO) "ASE-sample are installed on $(TARGET) in $(SAMPLES_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(SAMPLES_TARGET_DIR)"
	$(SCP_CMD)  $(SAMPLES_BUILD_DIR)/build/*  $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
	$(SCP_CMD) $(TOP)/lib.mk/run-sample.sh $(SSH_TARGET):$(SAMPLES_TARGET_DIR)

rdk-samples-clean:
	$(RM) -r $(SAMPLES_BUILD_DIR)
