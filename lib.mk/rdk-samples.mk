SAMPLES_TARGET_DIR=/opt/rdk-samples
SAMPLES_BUILD_DIR=$(TOP)/build/rdk-samples
RTE_TARGET=x86_64-native-linuxapp-gcc
DPDK_DIR=$(TOP)/build/dpdk-build/rdk_user/dpdk-$(BRANCH)

RDK_SAMPLES=crypto_inline \
	crypto_lookaside \
	data_path_sample_multiFlow \
	cpu_dsi_lpbk \
	cpu_inline_lpbk

help:: rdk-samples.help

rdk-samples.help:
	$(ECHO) "\n--- rdk-samples ---"
	$(ECHO) " rdk-samples-list          	: print a list of available rdk-samples"
	$(ECHO) " rdk-samples-build         	: build all rdk-samples"
	$(ECHO) " rdk-samples-deploy        	: deploy rdk-samples on target in $(SAMPLES_TARGET_DIR) directory"
	$(ECHO) " rdk-samples-clean         	: remove $(SAMPLES_BUILD_DIR) directory"

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
		cp -r $(AXXIA_RDK_SAMPLES)/common $(SAMPLES_BUILD_DIR) ; \
		cp -r $(AXXIA_RDK_SAMPLES)/shared $(SAMPLES_BUILD_DIR); \
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
	export RDK_INSTALL=$(DPDK_DIR) ; \
	cd $(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow/stats_monitor ; \
	echo "CFLAGS += -I$(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow" >> Makefile ; \
	sed -i s+./stats_monitor/build/stats_monitor+/opt/rdk-samples/stats_monitor+g $(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow/main.c ; \
	make ; \
	for dir in $(RDK_SAMPLES); do \
		cd $(SAMPLES_BUILD_DIR)/$$dir ; \
		make ; \
	done

rdk-samples-install:
	$(Q)if [ ! -d $(SAMPLES_BUILD_DIR)/build ]; then \
		mkdir -p $(SAMPLES_BUILD_DIR)/build; \
		cp $(SAMPLES_BUILD_DIR)/crypto_inline/build/snr_test $(SAMPLES_BUILD_DIR)/build/crypto_inline; \
		cp $(SAMPLES_BUILD_DIR)/crypto_lookaside/build/snr_test $(SAMPLES_BUILD_DIR)/build/crypto_lookaside; \
		cp $(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow/build/snr_test  $(SAMPLES_BUILD_DIR)/build/data_path_sample_multiFlow; \
		cp $(SAMPLES_BUILD_DIR)/cpu_dsi_lpbk/build/snr_test $(SAMPLES_BUILD_DIR)/build/cpu_dsi_lpbk ; \
		cp $(SAMPLES_BUILD_DIR)/cpu_dsi_lpbk/*.pcap $(SAMPLES_BUILD_DIR)/build ; \
		cp $(SAMPLES_BUILD_DIR)/cpu_inline_lpbk/build/snr_test $(SAMPLES_BUILD_DIR)/build/cpu_inline_lpbk ; \
		cp $(SAMPLES_BUILD_DIR)/cpu_inline_lpbk/*.pcap $(SAMPLES_BUILD_DIR)/build ; \
		cp $(SAMPLES_BUILD_DIR)/data_path_sample_multiFlow/stats_monitor/build/stats_monitor  $(SAMPLES_BUILD_DIR)/build ; \
	fi;

rdk-samples-deploy: rdk-samples-install
	$(ECHO) "ASE-sample are installed on $(TARGET) in $(SAMPLES_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(SAMPLES_TARGET_DIR)"
ifeq ($(SNR_RELEASE),)
	$(SCP_CMD)  $(SAMPLES_BUILD_DIR)/build/*  $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
	$(SCP_CMD) $(TOP)/scripts/run-sample.sh $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
else
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/run-sample.sh $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/crypto_inline/build/snr_test $(SSH_TARGET):$(SAMPLES_TARGET_DIR)/crypto_inline
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/crypto_lookaside/build/snr_test $(SSH_TARGET):$(SAMPLES_TARGET_DIR)/crypto_lookaside
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/data_path_sample_multiFlow/build/snr_test $(SSH_TARGET):$(SAMPLES_TARGET_DIR)/data_path_sample_multiFlow
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/cpu_dsi_lpbk/build/snr_test $(SSH_TARGET):$(SAMPLES_TARGET_DIR)/cpu_dsi_lpbk
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/cpu_dsi_lpbk/*.pcap $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/cpu_inline_lpbk/build/snr_test $(SSH_TARGET):$(SAMPLES_TARGET_DIR)/cpu_inline_lpbk
	$(SCP_CMD) $(SNR_REL_DIR)/$(SNR_RELEASE)/$(SAMPLES_TARGET_DIR)/cpu_inline_lpbk/*.pcap $(SSH_TARGET):$(SAMPLES_TARGET_DIR)
endif

rdk-samples-clean:
	$(RM) -r $(SAMPLES_BUILD_DIR)

rdk-samples-run-ase.%:
	$(Q)make sim-update RDK_SAMPLE=$* ; \
	echo "Starting ASE" ; \
	if [ $* == "cpu_dsi_lpbk" ] || [ $* == "cpu_inline_lpbk" ] ; then \
		tmux new-session -d -s aseConsole 'make sim-run > $(SAMPLES_BUILD_DIR)/ase_console.log' ; \
	else \
		tmux new-session -d -s aseConsole 'make sim-run-interactive > $(SAMPLES_BUILD_DIR)/ase_console.log' ; \
	fi ; \
	sleep 20 ; \
	echo "Booting Linux" ; \
	if [ $* != "cpu_dsi_lpbk" ] && [ $* != "cpu_inline_lpbk" ] ; then \
		tmux send-keys -t aseConsole -l 'start()' ; \
		tmux send-keys -t aseConsole Enter ; \
		tmux new-session -d -s linuxConsole 'make sim-connect > $(SAMPLES_BUILD_DIR)/linux_console.log' ; \
	fi ; \
	sleep 450 ; \
	echo "Logging in" ; \
	if [ $* == "cpu_dsi_lpbk" ] || [ $* == "cpu_inline_lpbk" ] ; then \
		tmux send-keys -t aseConsole -l 'root' ; \
		tmux send-keys -t aseConsole Enter ; \
	else \
		tmux send-keys -t linuxConsole -l 'root' ; \
		tmux send-keys -t linuxConsole Enter ; \
	fi ; \
	echo "Deploying required files" ; \
	make rdk-samples-deploy TARGET=ase-sim ; \
	sleep 2 ; \
	make dpdk-deploy TARGET=ase-sim ; \
	sleep 2 ; \
	echo "Running sample: $*" ; \
	if [ $* == "data_path_sample_multiFlow" ]; then \
		tmux send-keys -t linuxConsole -l '/opt/rdk-samples/run-sample.sh -s datapath' ; \
	elif [ $* == "crypto_inline" ] ; then \
		tmux send-keys -t linuxConsole -l '/opt/rdk-samples/run-sample.sh -s cryptoinline' ; \
	elif [ $* == "crypto_lookaside" ] ; then \
		tmux send-keys -t linuxConsole -l '/opt/rdk-samples/run-sample.sh -s cryptolookaside' ; \
	elif [ $* == "cpu_dsi_lpbk" ] ; then \
		tmux send-keys -t aseConsole -l '/opt/rdk-samples/run-sample.sh -s cpudsilpbk' ; \
	elif [ $* == "cpu_inline_lpbk" ] ; then \
		tmux send-keys -t aseConsole -l '/opt/rdk-samples/run-sample.sh -s cpuinlinelpbk' ; \
	fi ; \
	if [ $* != "cpu_dsi_lpbk" ] && [ $* != "cpu_inline_lpbk" ] ; then \
		tmux send-keys -t linuxConsole Enter ; \
		sleep 180 ; \
		tmux send-keys -t aseConsole -l 'load_traffic("tester.xml")' ; \
		tmux send-keys -t aseConsole Enter ; \
		sleep 5 ; \
		tmux send-keys -t linuxConsole Enter ; \
		sleep 2 ; \
		if [ $* == "crypto_lookaside" ]; then \
			tmux send-keys -t aseConsole -l 'run_traffic(13)' ; \
		else \
			tmux send-keys -t aseConsole -l 'run_traffic(1)' ; \
		fi ; \
		tmux send-keys -t aseConsole Enter ; \
		sleep 180 ; \
		tmux send-keys -t linuxConsole Enter ; \
		sleep 2 ; \
		tmux send-keys -t linuxConsole Enter ; \
		sleep 5 ; \
		tmux send-keys -t aseConsole -l 'run_test_analysis()' ; \
		tmux send-keys -t aseConsole Enter ; \
		sleep 5 ; \
		tmux send-keys -t aseConsole -l 'quit()' ; \
		tmux send-keys -t aseConsole Enter ; \
	else \
		tmux send-keys -t aseConsole Enter ; \
		sleep 450 ; \
	fi ; \
	tmux kill-session -t aseConsole 2> /dev/null || : ; \
	tmux-kill-session -t linuxConsole 2> /dev/null || : ; \
	make sim-stop > /dev/null ; \
	tail -n 10 $(SAMPLES_BUILD_DIR)/ase_console.log | grep -i "pass" > /dev/null ; \
	if [ $$? == 0 ] ; then \
		echo "[RDK SAMPLE PASSED]" ; \
		rm $(SAMPLES_BUILD_DIR)/ase_console.log ; \
		rm $(SAMPLES_BUILD_DIR)/linux_console.log ; \
		exit 0 ; \
	else \
		if [ $* == "cpu_dsi_lpbl" ] || [ $* == "cpu_inline_lpbk" ] ; then \
			cat $(SAMPLES_BUILD_DIR)/ase_console.log ; \
		else \
			cat $(SAMPLES_BUILD_DIR)/linux_console.log ; \
		fi ; \
		echo "[RDK SAMPLE FAILED]" ; \
		rm $(SAMPLES_BUILD_DIR)/ase_console.log ; \
		rm $(SAMPLES_BUILD_DIR)/linux_console.log ; \
		exit 1 ; \
	fi

rdk-samples-run-vlm.%:
	$(Q)if [ $* != "cpu_dsi_lpbk" ] && [ $* != "cpu_inline_lpbk" ] ; then \
		echo "The $* sample doesn't exit or is not supported on hardware." ; \
		exit 0 ; \
	fi ; \
	echo "Deploying required files" ; \
	make dpdk-deploy TARGET=$(TARGET) ; \
	make rdk-samples-deploy TARGET=$(TARGET) ; \
	echo "Running sample: $*" ; \
	if [ $* == "cpu_dsi_lpbk" ] ; then \
		ssh -p $(SSH_PORT) $(SSH_OPT) $(SSH_TARGET) -- "/opt/rdk-samples/run-sample.sh -s cpudsilpbk" &> $(SAMPLES_BUILD_DIR)/vlm_output.log ; \
	elif [ $* == "cpu_inline_lpbk" ] ; then \
		ssh -p $(SSH_PORT) $(SSH_OPT) $(SSH_TARGET) -- "/opt/rdk-samples/run-sample.sh -s cpuinlinelpbk" &> $(SAMPLES_BUILD_DIR)/vlm_output.log ; \
	fi ; \
	tail -n 10 $(SAMPLES_BUILD_DIR)/vlm_output.log | grep -i "pass" > /dev/null ; \
	if [ $$? == 0 ] ; then \
		echo "[RDK SAMPLE PASSED]" ; \
		rm $(SAMPLES_BUILD_DIR)/vlm_output.log ; \
		exit 0 ; \
	else \
		cat $(SAMPLES_BUILD_DIR)/vlm_output.log ; \
		echo "[RDK SAMPLE FAILED]" ; \
		rm $(SAMPLES_BUILD_DIR)/vlm_output.log ; \
		exit 1 ; \
	fi
