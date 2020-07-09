# Intel/Axxia stuff

RDK_SAMPLE ?= data_path_sample_multiFlow

ifeq ($(SNR_RELEASE),)

ifeq ($(RDK_SAMPLE),crypto_lookaside)
TOPOLOGY_TEMPLATE=$(SNR_SAMPLES_DIR)/$(RDK_SAMPLE)/snr_ase_project/topology.xml
TRAFFIC_TEMPLATE=$(SNR_SAMPLES_DIR)/$(RDK_SAMPLE)/snr_ase_project/tester.xml
else
TOPOLOGY_TEMPLATE=$(SNR_SAMPLES_DIR)/$(RDK_SAMPLE)/topology.xml
TRAFFIC_TEMPLATE=$(SNR_SAMPLES_DIR)/$(RDK_SAMPLE)/tester.xml
endif

USBDISK=$(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).hddimg
BIOS=$(SNR_ASE_DIR)/images/snr_bios.bin

else
ifeq ($(RDK_SAMPLE),crypto_lookaside)
TOPOLOGY_TEMPLATE=$(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/$(RDK_SAMPLE)/snr_ase_project/topology.xml
TRAFFIC_TEMPLATE=$(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/$(RDK_SAMPLE)/snr_ase_project/tester.xml
else
TOPOLOGY_TEMPLATE=$(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/$(RDK_SAMPLE)/topology.xml
TRAFFIC_TEMPLATE=$(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/$(RDK_SAMPLE)/tester.xml
endif

USBDISK=$(SNR_REL_DIR)/$(SNR_RELEASE)/$(IMAGE)-$(MACHINE).hddimg
BIOS=$(SNR_REL_DIR)/$(SNR_RELEASE)/snr_bios.bin
endif

TOPOLOGY=topology.xml
TRAFFIC=tester.xml
ASESIM=$(SNR_ASE_DIR)/asesim

export LM_LICENSE_FILE=$(WIND_INSTALL_BASE)/ASE/snowridge/licenses/simics-axxia-wr.lic
export SIMICS_LICENSE_FILE=$(LM_LICENSE_FILE)
export SIMICS_LICENSE_FEATURE=axxia_embed

# WindRiver stuff
BUILD_DIR=$(TOP)/build
PLATFORM=$(BUILD_DIR)/$(TARGET)

help:: sim-ase.help

sim-ase.help:
	$(ECHO) "\n--- sim-ase ---"
	$(ECHO) " sim-update RDK_SAMPLE=sample 	: Update all files used by the simulator inside build/ase-sim directory (SNR BIOS binary and the USB/SATA disk images from the WRL build),"
	$(ECHO) "                                   topology.xml and tester.xml templates are based from default rdk-sample: data_path_sample_multiFlow,"
	$(ECHO) "                                   run 'make rdk-samples-list', to see available rdk-samples which can be used with sim-ase."
	$(ECHO) " sim-run                      	: Run the simulator, using the files from build/ase-sim directory and connect to the simulator using telnet."
	$(ECHO) " sim-run-interactive	       	: Run the simulator in interactive mode (dropping to ASE python shell)"
	$(ECHO) " sim-stop                     	: Stop the simulator."

sim-samples: rdk-samples-list

sim-update:: ase.sim-update

ase.sim-update:
	$(MKDIR) $(PLATFORM) ;
	$(SCP) $(TOPOLOGY_TEMPLATE) $(PLATFORM) ;
ifeq (,$(filter $(RDK_SAMPLE),cpu_dsi_lpbk cpu_inline_lpbk))
	$(SCP) $(TRAFFIC_TEMPLATE) $(PLATFORM) ;
else
endif
	$(SCP) $(BIOS) $(PLATFORM) ;
	$(SCP) $(USBDISK) $(PLATFORM) ;
ifneq ($(TARGET),simics-sim)
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.spi0.nvm_image"]/@value' -v "$(PLATFORM)/$(shell basename $(BIOS))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.sata0.disk_image"]/@value' -v "$(PLATFORM)/$(shell basename $(USBDISK))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.usb0.disk_image"]/@value' -v "$(PLATFORM)/$(shell basename $(USBDISK))" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="cpu.real_time_scale_factor"]/@value' -v "1" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -u 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="pch.enet.enable_host_services"]/@value' -v "true" $(PLATFORM)/$(TOPOLOGY) ;
	$(XMLSTARLET) ed --inplace -d 'topology:Topology/Devices/Device/SimParameters/SimParameter[@name="internal_platform"]' $(PLATFORM)/$(TOPOLOGY) ;
endif

sim-start:: ase.sim-start

ase.sim-start:
	$(Q)if [ ! -d $(PLATFORM) ] || [ ! -f $(PLATFORM)/$(shell basename $(BIOS)) ] || \
        [ ! -f $(PLATFORM)/$(shell basename $(USBDISK)) ] || [ ! -f $(PLATFORM)/$(shell basename $(TOPOLOGY)) ] ; then \
                echo "You are missing a required file, please run \"make sim-update\" first." ; \
                exit 1 ; \
	fi ;
ifneq ($(TARGET),simics-sim)
	$(Q)if [ ! -f $(PLATFORM)/$(SIM).sim.pid ]; then \
		cd $(PLATFORM) ; \
		rm $(PLATFORM)/*.log 2>/dev/null ; \
		$(ASESIM) -N -t $(TOPOLOGY) -c $(TRAFFIC) -l file >stdout.log 2>stderr.log & \
		echo $$! > $(PLATFORM)/$(SIM).sim.pid ; \
	else \
		echo 'Another asesim process is running, run "make sim-stop" command first.' ; \
		exit 1; \
	fi
endif

sim-run-interactive:: ase.sim-run-interactive

ase.sim-run-interactive:
	$(Q)if [ ! -d $(PLATFORM) ] || [ ! -f $(PLATFORM)/$(shell basename $(BIOS)) ] || \
	[ ! -f $(PLATFORM)/$(shell basename $(USBDISK)) ] || [ ! -f $(PLATFORM)/$(shell basename $(TOPOLOGY)) ] ; then \
		echo "You are missing a required file, please run \"make sim-update\" first." ; \
		exit 1 ; \
	fi ;
ifneq ($(TARGET),simics-sim)
	$(Q)if [ ! -f $(PLATFORM)/$(SIM).sim.pid ]; then \
		cd $(PLATFORM) ; \
		rm $(PLATFORM)/*.log 2>/dev/null ; \
		$(ASESIM) -i -t $(TOPOLOGY) -c $(TRAFFIC) -l file ; \
	else \
		echo 'Another asesim process is running, run "make sim-stop" command first.' ; \
		exit 1; \
	fi
endif

sim-connect:
	$(ECHO) "Waiting to get telnet port..." ; \
	TIMEOUT=0; while [ -z $$TELNET_PORT ] && [ $$TIMEOUT -lt 120 ] ; do \
		TELNET_PORT=$$(grep -m 1 -a "Telnet console listening to port" $(PLATFORM)/$(SIM).sim.log 2>/dev/null | sed 's/[^0-9]*//g') ; \
		TIMEOUT=$$(($$TIMEOUT+5)) ; \
		echo "." ; \
		sleep 5 ; \
	done ; \
	if [ $$TIMEOUT == 120 ] ; then \
		echo "Could not get telnet port, check $(PLATFORM)/$(SIM).sim.log" ; \
	else \
		echo "Got telnet port $$TELNET_PORT, connecting..." ; \
		telnet localhost $$TELNET_PORT ; \
	fi

sim-run:: ase.sim-run

ase.sim-run:
ifneq ($(TARGET),simics-sim)
	$(MAKE) ase.sim-start
	$(MAKE) sim-connect
endif

sim-stop:
	$(Q)if [ -f $(PLATFORM)/$(SIM).sim.pid ]; then \
		SIM_PID=$$(cat $(PLATFORM)/$(SIM).sim.pid); \
		if [ "$$SIM_PID" != "" ]; then \
			SIM_GPID=$$(ps -o pid,pgid -U $$USER | grep $$SIM_PID | awk '{print $$2}'); \
			echo "Stopping all sim related processes having GPID:$$SIM_GPID"; \
			pkill -9 -g $$SIM_GPID 2>/dev/null || echo "Process was already stopped."; \
		fi; \
		rm $(PLATFORM)/$(SIM).sim.pid ; \
	fi
