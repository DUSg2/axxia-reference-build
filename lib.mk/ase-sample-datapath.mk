help:: ase-sample-datapath.help

ase-sample-datapath.help:
	$(ECHO) "\n--- ase-sample-datapata ---"
	$(ECHO) " build-rdk-sample-datapath : builds datapath sample"
	$(ECHO) " run-rdk-sample-datapath   : runs datapath sample"

build-rdk-sample-datapath:
	$(Q)if [ ! -d $(TOP)/build/samples ]; then \
		mkdir $(TOP)/build/samples ; \
		cp -r $(AXXIA_RDK_SAMPLES)/data_path_sample_multiFlow $(TOP)/build/samples ; \
	fi; \
	cd $(TOP)/build/samples/data_path_sample_multiFlow ; \
	source $(SDK_ENV) ; \
	export RTE_SDK=$(TOP)/build/dpdk ; \
	make clean ; \
	export LIB_CPKAE_DIR=$$SDKTARGETSYSROOT/usr/lib64 ;\
	make CROSS=$$CROSS_COMPILE EXTRA_CFLAGS=" -msse4.2 $$KCFLAGS" LIB_QAT18_DIR=$$OECORE_TARGET_SYSROOT/usr LDFLAGS=" -lies_sdk -lae_client -lrte_pmd_ice_dsi"

$(TOP)/build/samples/data_path_sample_multiFlow/datapath-run.sh:
	$(ECHO) "modprobe ice_sw" > $@
	$(ECHO) "modprobe ice_sw_ae" >> $@
	$(ECHO) "modprobe ies" >> $@
	$(ECHO) "modprobe hqm" >> $@
	$(ECHO) "mkdir -p /mnt/hugepages" >> $@
	$(ECHO) "mount -t hugetlbfs hugetlbfs /mnt/hugepages" >> $@
	$(ECHO) "echo 256 > /proc/sys/vm/nr_hugepages" >> $@
	$(ECHO) "sleep 10 ; # need some time for things to settle down... " >> $@
	$(ECHO) "./snr_test -c 1 -n 4 --vdev=net_ice_dsi0,pci-bdf=b4:00.0,rxq=21,txq=21 --vdev=event_ihqm,dir_port_ids=4:5,dir_queue_ids=5:4 --lcores '(0-4)@0' -- -t 1" >> $@

SNR_SSH_PORT:=$(shell grep ^"Host TCP port" build/ase-sim/ase.sim.log 2>/dev/null | grep 22 | cut -d" " -f 4)

run-rdk-sample-datapath: $(TOP)/build/samples/data_path_sample_multiFlow/build/app/snr_test $(TOP)/build/samples/data_path_sample_multiFlow/datapath-run.sh
	$(SCP) -P $(SNR_SSH_PORT) $^ root@localhost:
	$(SSH) -p $(SNR_SSH_PORT) root@localhost sh -x datapath-run.sh
