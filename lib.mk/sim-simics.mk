SIMICS_BASE=$(shell find $(SNR_ASE_DIR)/simics/ -maxdepth 1 -type d -name 'simics-[0-9]*')
NAC=$(SNR_ASE_DIR)/images/nis_nvm.bin

# WindRiver simics license
SNR_SIMICS_LICENSE_FILE=$(WIND_INSTALL_BASE)/ASE/snowridge/licenses/simics-wr.lic


help:: sim-simics.help

sim-simics.help:
	$(ECHO) "\n--- sim-simics ---"
	$(ECHO) " sim-run                : Run the simulator, dropping to a simics shell"
	$(ECHO) " sim-connect            : Connect to the simulated target using telnet."
	$(ECHO) " sim-load-checkpoint    : Load a stored simulation."
	$(ECHO) " sim-stop               : Stop the simulator."

sim-update:: simics.sim-update

simics.sim-update:
ifeq ($(TARGET),simics-sim)
	$(Q) if [ ! -d $(PLATFORM) ]; then \
		$(SIMICS_BASE)/bin/project-setup $(PLATFORM) --package-list $(SIMICS_BASE)/.package-list ; \
		mkdir -p $(PLATFORM)/targets/snr/ ; \
	fi
	$(SCP) $(NAC) $(PLATFORM) ;
	$(SCP) $(TOP)/examples/simics/snr.include $(PLATFORM)/targets/snr/ ;
	$(Q) grep -n "# Auto-generated file path. Don't replace!" examples/simics/snr.simics | \
            cut -d':' -f1 | \
            xargs -I {} head -{} examples/simics/snr.simics > $(PLATFORM)/targets/snr/head.fragment ;
	$(Q) grep -n "# Auto-generated file path. Don't replace!" examples/simics/snr.simics | \
            cut -d':' -f1 | \
            xargs -I {} tail -n +{} examples/simics/snr.simics > $(PLATFORM)/targets/snr/tail.fragment ;
	$(Q) find $(SNR_ASE_DIR) -type f -name 'jacobsville-fedora26.simics' -exec readlink -f '{}' \; | \
            xargs -I {} echo "run-command-file \"{}\"" > $(PLATFORM)/targets/snr/path.fragment ;
	$(Q) cat $(PLATFORM)/targets/snr/*.fragment > $(PLATFORM)/targets/snr/snr.simics ;
	$(RM) $(PLATFORM)/targets/snr/*.fragment ;
endif

sim-run-interactive:: simics.sim-run-interactive

simics.sim-run-interactive:
ifeq ($(TARGET),simics-sim)
	$(Q) if [ -d $(PLATFORM) ]; then \
		rm $(PLATFORM)/*.log 2>/dev/null ; \
		cd $(PLATFORM) ; \
		./simics \
            -no-gui \
            -license-file $(SNR_SIMICS_LICENSE_FILE) \
            targets/snr/snr.simics \
            bios=$(shell basename $(BIOS)) \
            disk_image=$(shell basename $(USBDISK)) \
            usb2_disk_image=$(shell basename $(USBDISK)) \
            cpk_flash_image=$(shell basename $(NAC)) ; \
		rm $(PLATFORM)/*.log 2>/dev/null ; \
	fi
endif

sim-load-checkpoint:
	$(Q) if [ -d $(PLATFORM) ]; then \
		echo "searching for the checkpoint..." ; \
		cd $(PLATFORM) ; \
		CHKPT=$$(grep -a 'default checkpoint_filename' targets/snr/snr.simics | cut -d"=" -f2 | cut -d"\"" -f2) ; \
		if [ -d $$CHKPT ]; then \
			./simics -no-gui -license-file $(SNR_SIMICS_LICENSE_FILE) -c $$CHKPT ; \
		fi ; \
	fi

sim-run:: simics.sim-run

simics.sim-run:
ifeq ($(TARGET),simics-sim)
	$(ECHO) "running sim-run-interactive.\nRun 'make sim-connect' in another terminal to connect to the simulation.\n"
	$(MAKE) simics.sim-run-interactive
endif
