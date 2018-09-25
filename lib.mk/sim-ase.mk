# Intel/Axxia stuff
TOPOLOGY_TEMPLATE=$(SNR_SAMPLES_DIR)/data_path_sample_multiFlow/topology.xml
TOPOLOGY=topology.xml
BIOS=$(SNR_ASE_DIR)/images/snr_bios.bin
ASESIM=$(SNR_ASE_DIR)/asesim

export LM_LICENSE_FILE=/wr/installs/ASE/snowridge/licenses/simics-axxia-wr.lic
export SIMICS_LICENSE_FILE=$(LM_LICENSE_FILE)
export SIMICS_LICENSE_FEATURE=axxia_embed

# WindRiver stuff
BUILD_DIR=$(TOP)/build
SATADISK=$(BUILD_DIR)/build/tmp/deploy/images/axxiax86-64/axxia-image-sim-axxiax86-64.hddimg
USBDISK=$(BUILD_DIR)/build/tmp/deploy/images/axxiax86-64/axxia-image-sim-axxiax86-64.ext4
PLATFORM=$(BUILD_DIR)/ase-sim

help:: sim-ase.help

sim-ase.help:
	$(ECHO) "\n--- sim-ase ---"
	$(ECHO) " sim-update 		   : Update all files used by the simulator inside build/ase-sim directory (SNR BIOS binary, topology.xml and the USB/SATA disk images from the WRL build)."
	$(ECHO) " sim-run                  : Run the simulator, using the files from build/ase-sim directory and connect to the simulator using telnet."
	$(ECHO) " sim-stop                 : Stop the simulator."


sim-update:
	$(MKDIR) $(PLATFORM) ;
	$(SCP) $(TOPOLOGY_TEMPLATE) $(PLATFORM) ;
	$(SCP) $(BIOS) $(PLATFORM) ;
	$(SCP) $(SATADISK) $(PLATFORM) ;
	$(SCP) $(USBDISK) $(PLATFORM) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.spi0.nvm_image"]/@value' -v "$(PLATFORM)/$(shell basename $(BIOS))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.sata0.disk_image"]/@value' -v "$(PLATFORM)/$(shell basename $(SATADISK))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.usb0.disk_image"]/@value' -v "$(PLATFORM)/$(shell basename $(USBDISK))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="cpu.real_time_scale_factor"]/@value' -v "1" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.enet.enable_host_services"]/@value' -v "true" $(PLATFORM)/$(TOPOLOGY)

sim-start:
	$(Q)if [ ! -d $(PLATFORM) ] || [ ! -f $(PLATFORM)/$(shell basename $(BIOS)) ] || [ ! -f $(PLATFORM)/$(shell basename $(SATADISK)) ] || \
        [ ! -f $(PLATFORM)/$(shell basename $(USBDISK)) ] || [ ! -f $(PLATFORM)/$(shell basename $(TOPOLOGY)) ] ; then \
                echo "You are missing a required file, please run \"make sim-update\" first." ; \
                exit 1 ; \
	fi ;
	$(Q)if [ ! -f $(PLATFORM)/ase.sim.pid ]; then \
		cd $(PLATFORM) ; \
		rm $(PLATFORM)/*.log 2>/dev/null ; \
		$(ASESIM) -N -t $(TOPOLOGY) -l file >stdout.log 2>stderr.log & \
		echo $$! > $(PLATFORM)/ase.sim.pid ; \
	else \
		echo 'Another asesim process is running, run "make sim-stop" command first.' ; \
		exit 1; \
	fi

sim-run: sim-start
	$(Q)while [ -z $$TELNET_PORT ] ; do \
		TELNET_PORT=$$(grep "Telnet console listening to port" $(PLATFORM)/ase.sim.log 2>/dev/null | sed 's/[^0-9]*//g') ; \
		sleep 5 ; \
	done ; \
	echo "Got telnet port $$TELNET_PORT, connecting..." ; \
	telnet localhost $$TELNET_PORT

sim-stop:
	$(Q)if [ -f $(PLATFORM)/ase.sim.pid ]; then \
		ASE_PID=$$(cat $(PLATFORM)/ase.sim.pid); \
		if [ "$$ASE_PID" != "" ]; then \
			ASE_GPID=$$(ps -o pid,pgid -U $$USER | grep $$ASE_PID | awk '{print $$2}'); \
			echo "Stopping all asesim related processes having GPID:$$ASE_GPID"; \
			pkill -9 -g $$ASE_GPID || echo "Process was already stopped."; \
		fi; \
		rm $(PLATFORM)/ase.sim.pid ; \
	fi
