ASE_TARGET_DIR=/opt/ase-samples
ASE_BUILD_DIR=$(TOP)/build/ase-samples
RTE_TARGET=x86_64-native-linuxapp-gcc

ASE_SAMPLES=cpk \
	    crypto_inline \
	    crypto_lookaside \
	    data_path_sample_multiFlow \
	    dfx/application \
	    dsi_Lan_trafficTest \
	    external_device \
	    io_widget/application \
	    io_widget/i2c_eeprom \
	    io_widget/mdio_phy \
	    PortSetMode

help:: ase-samples.help

ase-samples.help:
	$(ECHO) "\n--- ase-samples ---"
	$(ECHO) " ase-samples-list          : print list of ase-samples"
	$(ECHO) " ase-samples-build         : builds all ase-samples"
	$(ECHO) " ase-samples-deploy        : deploys ase-samples on target in $(ASE_TARGET_DIR) directory"
	$(ECHO) " ase-samples-clean         : removes $(ASE_BUILD_DIR) directory"

ase-samples-list:
	$(ECHO) List of ase-samples to build is: $(ASE_SAMPLES)

ase-samples-fetch:
	$(Q)if [ ! -d $(DPDK_BUILD_DIR) ]; then \
		echo 'DPDK libraries are not built. Run first "make dpdk-build" command.'; \
		exit 1; \
	fi;
	$(Q)if [ ! -d $(ASE_BUILD_DIR) ]; then \
		mkdir $(ASE_BUILD_DIR) ; \
		for dir in $(ASE_SAMPLES); do \
			if [ "$$dir" == "dfx/application" ] ; then \
				mkdir -p $(ASE_BUILD_DIR)/dfx; \
				cp -r $(AXXIA_RDK_SAMPLES)/$$dir $(ASE_BUILD_DIR)/dfx; \
			elif [ "$$dir" == "io_widget/application" ] || \
				[ "$$dir" == "io_widget/i2c_eeprom" ] || \
				[ "$$dir" == "io_widget/mdio_phy" ] ; then \
				mkdir -p $(ASE_BUILD_DIR)/io_widget; \
				cp -r $(AXXIA_RDK_SAMPLES)/$$dir $(ASE_BUILD_DIR)/io_widget; \
			else \
				cp -r $(AXXIA_RDK_SAMPLES)/$$dir $(ASE_BUILD_DIR); \
			fi; \
		done; \
	fi;

ase-samples-build: ase-samples-fetch
	$(Q)source $(SDK_ENV) ; \
	touch $(ASE_BUILD_DIR)/g++; \
	export RTE_SDK=$(TOP)/build/dpdk ; \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib64 ;\
	export HLP_LIBDIR=$$SDKTARGETSYSROOT/usr/lib64 ;\
	export ASE_INSTALL=$(SNR_ASE_DIR) ;\
	export SDK_HOME=$(SNR_ASE_DIR) ;\
	export GCC_PATH=$(ASE_BUILD_DIR); \
	for dir in $(ASE_SAMPLES); do \
		cd $(ASE_BUILD_DIR)/$$dir ; \
		make -s clean ; \
		make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS" \
		     LIB_QAT18_DIR=$$OECORE_TARGET_SYSROOT/usr \
		     LDFLAGS="-L$$RTE_SDK/$(RTE_TARGET)/lib  -lies_sdk -lae_client -lrte_pmd_ice_dsi" \
		     LIBRARY="-L$$HLP_LIBDIR -lies_sdk -lpthread" \
		     CXX="$$CXX" DEFINES="-DNCP_LINUX -shared" ; \
	done;

ase-samples-install:
	$(Q)if [ ! -d $(ASE_BUILD_DIR)/build ]; then \
		mkdir -p $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/cpk/cpk_loopback $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/crypto_inline/build/snr_test $(ASE_BUILD_DIR)/build/crypto_inline; \
		cp $(ASE_BUILD_DIR)/crypto_lookaside/build/snr_test $(ASE_BUILD_DIR)/build/crypto_lookaside; \
		cp $(ASE_BUILD_DIR)/dfx/application/dfx $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/data_path_sample_multiFlow/build/snr_test  $(ASE_BUILD_DIR)/build/data_path_sample_multiFlow; \
		cp $(ASE_BUILD_DIR)/external_device/libexternal_device.so $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/io_widget/application/io_widget $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/io_widget/i2c_eeprom/libsim_i2c_eeprom.so $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/io_widget/mdio_phy/libsim_mdio_phy.so $(ASE_BUILD_DIR)/build; \
		cp $(ASE_BUILD_DIR)/PortSetMode/snrPortSetMode $(ASE_BUILD_DIR)/build/snrPortSetMode ; \
	fi;

ase-samples-deploy: ase-samples-install
	$(ECHO) "ASE-sample are installed on $(TARGET) in $(ASE_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(ASE_TARGET_DIR)"
	$(SCP_CMD)  $(ASE_BUILD_DIR)/build/*  $(SSH_TARGET):$(ASE_TARGET_DIR)

ase-samples-clean:
	$(RM) $(ASE_BUILD_DIR)
