
BRANCH=18.05
SRCREV = "a5dce55556286cc56655320d975c67b0dbe08693"
DPDK_DIR=$(TOP)/build/dpdk
DPDK_PATCH=$(ASE_BASE)/dpdk_diff_snr*.patch

RTE_TARGET=x86_64-native-linuxapp-gcc
RTE_DEFCONFIG="$(DPDK_DIR)/config/defconfig_${RTE_TARGET}"
DPDK_TARGET_MACH=default
CONFIG_VHOST_ENABLED=n
CONFIG_HAVE_NUMA=y
CONFIG_EXAMPLE_VM_POWER_MANAGER=n

SDK_ENV=$(TOP)/build/sdk/environment-setup-core2-64-intelaxxia-linux

help:: dpdk.help

dpdk.help:
	$(ECHO) "\n--- dpdk ----"
	$(ECHO) " dpdk-build                : builds dpdk"
	$(ECHO) " dpdk-build-examples       : builds dpdk examples"
	$(ECHO) " dpdk-build-tests          : builds dpdk tests"
	$(ECHO) " dpdk-clean                : deletes $(DPDK_DIR) directory"


dpdk-fetch:
	$(Q)if [ ! -d $(DPDK_DIR) ]; then \
		git clone --single-branch git://dpdk.org/dpdk-stable -b $(BRANCH) $(DPDK_DIR); \
		cd $(DPDK_DIR) ; \
		git checkout $(SRCREV); \
		cp $(DPDK_PATCH) $(DPDK_DIR)/dpdk_diff_snr.patch; \
		patch -p1 -s < $(DPDK_DIR)/dpdk_diff_snr.patch ;\
	fi;

dpdk-config: dpdk-fetch
	$(Q)if [ ! -d $(DPDK_DIR)/$(RTE_TARGET) ]; then \
		echo "CONFIG_RTE_BUILD_SHARED_LIB=y"               >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_MAX_MEMZONE=10240"                >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_EAL_NUMA_AWARE_HUGEPAGES=y"       >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_MAX_QUEUES_PER_PORT=16384"        >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_PMD_PCAP=y"                >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_PMD_IHQM_EVENTDEV_DEBUG=y" >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_PMD_QAT=y"                 >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_PMD_QAT_DEBUG_DRIVER=y"    >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_POWER=y"                   >> $(RTE_DEFCONFIG); \
		echo "CONFIG_RTE_LIBRTE_VHOST_NUMA=y"              >> $(RTE_DEFCONFIG); \
		echo 'CONFIG_RTE_MACHINE="x86-64"'                 >> $(RTE_DEFCONFIG); \
		sed -e "s#CONFIG_RTE_MACHINE=\"native\"#CONFIG_RTE_MACHINE=\"$(DPDK_TARGET_MACH)\"#" -i $(DPDK_DIR)/config/defconfig_${RTE_TARGET}; \
		sed -e "s#CONFIG_RTE_KNI_VHOST=n#CONFIG_RTE_KNI_VHOST=$(CONFIG_VHOST_ENABLED)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		sed -e "s#CONFIG_RTE_KNI_VHOST_VNET_HDR_EN=n#CONFIG_RTE_KNI_VHOST_VNET_HDR_EN=$(CONFIG_VHOST_ENABLED)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		sed -e "s#CONFIG_RTE_LIBRTE_VHOST=n#CONFIG_RTE_LIBRTE_VHOST=$(CONFIG_VHOST_ENABLED)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		sed -e "s#CONFIG_RTE_LIBRTE_VHOST_NUMA=.*#CONFIG_RTE_LIBRTE_VHOST_NUMA=$(CONFIG_HAVE_NUMA)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		sed -e "s#CONFIG_RTE_EAL_NUMA_AWARE_HUGEPAGES=.*#CONFIG_RTE_EAL_NUMA_AWARE_HUGEPAGES=$(CONFIG_HAVE_NUMA)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		sed -e "s#CONFIG_RTE_LIBRTE_POWER=y#CONFIG_RTE_LIBRTE_POWER=$(CONFIG_EXAMPLE_VM_POWER_MANAGER)#" -i $(DPDK_DIR)/config/common_linuxapp; \
		cd $(DPDK_DIR) ; \
		source $(SDK_ENV) ; \
		make O=$(RTE_TARGET) T=$(RTE_TARGET) config ;\
	fi;

dpdk-build: dpdk-config
	$(CD) $(DPDK_DIR)/$(RTE_TARGET); \
	source $(SDK_ENV) ; \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
	export IES_API_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
	export LIB_QAT18_DIR=$$SDKTARGETSYSROOT/usr/lib; \
	make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS";

dpdk-build-examples: dpdk-config
	$(CD) $(DPDK_DIR)/examples; \
	source $(SDK_ENV) ; \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
	export IES_API_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
	export LIB_QAT18_DIR=$$SDKTARGETSYSROOT/usr/lib; \
	export RTE_SDK=$(DPDK_DIR); \
        export RTE_TARGET=$(RTE_TARGET); \
	make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS";

dpdk-build-tests: dpdk-config
	$(CD) $(DPDK_DIR)/test; \
        source $(SDK_ENV) ; \
        export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
        export IES_API_DIR=$$SDKTARGETSYSROOT/usr/lib ; \
        export LIB_QAT18_DIR=$$SDKTARGETSYSROOT/usr/lib; \
	export RTE_SDK=$(DPDK_DIR); \
	export RTE_TARGET=$(RTE_TARGET); \
        make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS";

dpdk-clean:
	$(RM) -r $(DPDK_DIR)
