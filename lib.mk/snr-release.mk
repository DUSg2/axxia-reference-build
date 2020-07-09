SNR_REL_DIR = /wr/projects/eri/rcs/binrelease/$(MACHINE)/$(REL)
SNR_TAG = $(shell git describe --abbrev=0 --tags)
SNR_TAG_STATE = $(shell git describe --tags)
REPO_STATUS = "$(shell git status --porcelain)"

help:: snr-release.help

snr-release.help:
	$(ECHO) "\n--- snr-release ----"
	$(ECHO) " snr-release-export		: build and export a binary release which includes everything used in deploying/testing"
	$(ECHO) " snr-release-list		: list all exported releases"
	$(ECHO) " snr-release-remove		: remove a release from the exported directory"


snr-check-files:
	$(Q) if [ ! -f $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).tar.bz2 ] ; then \
		echo -e "$(INFO_MSG) No WRL image found, building..." ; \
		make -s image $(NO_STDOUT); \
		echo -e "$(GREEN_TICK) WRL image built."; \
	else \
		echo -e "$(GREEN_TICK) Found WRL rootfs image." ; \
	fi
	
	$(Q) if [ ! -d $(DPDK_BUILD_DIR) ] ; then \
		echo -e "$(INFO_MSG) No DPDK libs found, building..." ; \
		if [ ! -f $(SDK_ENV) ] ; then \
			echo -e "$(INFO_MSG) No SDK found, building..." ; \
			make -s sdk-build $(NO_STDOUT) ; \
			make -s sdk-install $(NO_STDOUT) ; \
			echo -e "$(GREEN_TICK) SDK built." ; \
		else \
			echo -e "$(GREEN_TICK) Found SDK." ; \
		fi ; \
		make -s dpdk-build $(NO_STDOUT) ; \
		echo -e "$(GREEN_TICK) DPDK libs built." ; \
	else \
		echo -e "$(GREEN_TICK) Found DPDK libs." ; \
	fi
	
	$(Q) if [ ! -d $(ADK_DIR) ] ; then \
		echo -e "$(INFO_MSG) No ADK libs found, building..." ; \
		if [ ! -f $(SDK_ENV) ] ; then \
			echo -e "$(INFO_MSG) No SDK found, building..." ; \
			make -s sdk-build $(NO_STDOUT) ; \
			make -s sdk-install $(NO_STDOUT) ; \
                        echo -e "$(GREEN_TICK) SDK built." ; \
		else \
			echo -e "$(GREEN_TICK) Found SDK." ; \
		fi ; \
		make -s adk-build-apps $(NO_STDOUT) ; \
		echo -e "$(GREEN_TICK) ADK libs built." ; \
	else \
		echo -e "$(GREEN_TICK) Found ADK libs." ; \
	fi
	
	$(Q) if [ ! -d $(SAMPLES_BUILD_DIR) ] ; then \
		echo -e "$(INFO_MSG) No RDK samples found, building..." ; \
		if [ ! -f $(SDK_ENV) ] ; then \
			echo -e "$(INFO_MSG) No SDK found, building..." ; \
			make -s sdk-build $(NO_STDOUT) ; \
			make -s sdk-install $(NO_STDOUT) ; \
			echo -e "$(GREEN_TICK) SDK built." ; \
		else \
			echo -e "$(GREEN_TICK) Found SDK." ; \
		fi ; \
		make -s rdk-samples-build $(NO_STDOUT) 2>/dev/null ; \
		echo -e "$(GREEN_TICK) RDK samples built." ; \
	else \
		echo -e "$(GREEN_TICK) Found RDK samples." ; \
	fi
	
	$(Q) if [ ! -f $(BIOS) ] ; then \
		echo -e "$(RED_CROSS) ASE BIOS file not found, please check ASE installation." ; \
	else \
		echo -e "$(GREEN_TICK) Found ASE BIOS file." ; \
	fi


snr-release-export:
	$(Q)if [ ! -z $(REPO_STATUS) ] ; then \
		echo -e "$(INFO_MSG) This is a dirty git repository. Please commit/tag all the work before exporting a release." ; \
	elif [ $(SNR_TAG) != $(SNR_TAG_STATE) ] ; then \
		echo -e "$(INFO_MSG) There are commits on top of the latest tag. Please make sure the release tag is up-to-date." ; \
	elif [ -d $(SNR_REL_DIR)/$(SNR_TAG) ] ; then \
		echo -e "$(INFO_MSG) The $(COL_LIGHT_GREEN)$(SNR_TAG)$(COL_NC) release was already exported." ; \
	else \
		make snr-check-files ; \
		echo -e "$(INFO_MSG) Exporting all release files." ; \
		mkdir -p $(SNR_REL_DIR)/$(SNR_TAG) ; \
		scp $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).tar.bz2 $(SNR_REL_DIR)/$(SNR_TAG) ; \
		scp $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).ext4 $(SNR_REL_DIR)/$(SNR_TAG) ; \
		scp $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).hddimg $(SNR_REL_DIR)/$(SNR_TAG) ; \
		scp $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/bzImage $(SNR_REL_DIR)/$(SNR_TAG) ; \
		mkdir -p $(SNR_REL_DIR)/$(SNR_TAG)/$(DPDK_TARGET_DIR)/usertools ; \
		scp -r $(DPDK_DIR)/$(RTE_TARGET)/lib $(SNR_REL_DIR)/$(SNR_TAG)/$(DPDK_TARGET_DIR) ; \
		scp $(DPDK_DIR)/usertools/dpdk-devbind.py $(SNR_REL_DIR)/$(SNR_TAG)/$(DPDK_TARGET_DIR)/usertools ; \
		scp -r $(DPDK_DIR)/$(RTE_TARGET)/kmod $(SNR_REL_DIR)/$(SNR_TAG)/$(DPDK_TARGET_DIR) ; \
		mkdir -p $(SNR_REL_DIR)/$(SNR_TAG)/$(ADK_TARGET_DIR) ; \
		scp $(ADK_SRC)/build/* $(SNR_REL_DIR)/$(SNR_TAG)/$(ADK_TARGET_DIR) ; \
		scp $(TOP)/lib.mk/adk-test.sh $(SNR_REL_DIR)/$(SNR_TAG)/$(ADK_TARGET_DIR) ; \
		mkdir -p $(SNR_REL_DIR)/$(SNR_TAG)/$(SAMPLES_TARGET_DIR) ; \
		scp -r $(SAMPLES_BUILD_DIR)/* $(SNR_REL_DIR)/$(SNR_TAG)/$(SAMPLES_TARGET_DIR) ; \
		scp $(TOP)/lib.mk/run-sample.sh $(SNR_REL_DIR)/$(SNR_TAG)/$(SAMPLES_TARGET_DIR) ; \
		scp $(BIOS) $(SNR_REL_DIR)/$(SNR_TAG) ; \
		echo -e "$(GREEN_TICK) $(COL_LIGHT_GREEN) Release exported successfully! $(COL_NC)" ; \
	fi

snr-release-list:
	$(Q)ls -1 $(SNR_REL_DIR)

snr-release-remove:
	$(Q)if [ ! -d $(SNR_REL_DIR)/$(SNR_RELEASE) ] ; then \
		echo -e "$(RED_CROSS) The release you're trying to remove doesn't exist. $(COL_NC)" ; \
	else \
		rm -rf $(SNR_REL_DIR)/$(SNR_RELEASE) ; \
		echo -e "$(GREEN_TICK) Release removed successfully. $(COL_NC)" ; \
	fi
