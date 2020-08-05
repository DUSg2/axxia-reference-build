# hostconfig-arn-build3.mk

VLMTOOL=/home/bsandu/vlm/commandline/vlmTool

# VLM targets
ifeq ($(TARGET),vlm_snr2)
SSH_PORT   := 22
SSH_IP     := 128.224.95.160
VLM_ID     := 98981070
endif

ifeq ($(TARGET),vlm_epb2_1)
SSH_PORT   := 22
SSH_IP     := 128.224.95.140
VLM_ID     := 98981049
endif

ifeq ($(TARGET),vlm_epb2_2)
SSH_PORT   := 22
SSH_IP     := 128.224.95.141
VLM_ID     := 98981058
endif

vlm-check-target: vlm-check-id
	@TARGET_USER=$$($(VLMTOOL) getAttr -t $(VLM_ID) all | grep -i "reserved by" | cut -d ":" -f 2 | tr -d " ") ; \
	if [ ! -z $$TARGET_USER ]; then \
		echo "The $(TARGET) target is reserved by $$TARGET_USER." ; \
	else \
		echo "The $(TARGET) target is not reserved." ; \
	fi

vlm-deploy-kernel: vlm-check-id
	$(ECHO) -n "Checking target is reserved..."
	$(ECHO) " OK";
	$(ECHO) "Powering target off"
	@$(VLMTOOL) turnOff -t $(VLM_ID)
	$(ECHO) "Transfering kernel to vlm server"
	@scp $(TOP)/build/build/tmp/deploy/images/$(MACHINE)/bzImage $(TUXLAB):
	#@scp $(TOP)/bzImage $(TUXLAB):
	$(ECHO) "Setting up VLM with new kernel/rootfs"
	@$(VLMTOOL) copyFile -t $(VLM_ID) -k \~/bzImage
	$(ECHO) "Powering target on"
	@$(VLMTOOL) turnOn -t $(VLM_ID)

vlm-deploy-rootfs: vlm-check-id
	$(ECHO) -n "Checking target is reserved..."
	@status=$$($(VLMTOOL) findMine | grep $(VLM_ID)) ;\
	if [ "$$status" != "$(VLM_ID)" ]; then \
		echo " ooops it wasn't. bailing out." ;\
		exit 1 ;\
	fi
	$(ECHO) " OK";
	$(ECHO) "Powering target off"
	@$(VLMTOOL) turnOff -t $(VLM_ID)
	$(ECHO) "Transfering rootfs to vlm server"
	@scp $(TOP)/build/build/tmp-glibc/deploy/images/$(MACHINE)/$(IMAGE)-$(MACHINE).tar.bz2 $(TUXLAB):
	$(ECHO) "Setting up VLM with new kernel/rootfs"
	@$(VLMTOOL) copyFile -t $(VLM_ID) -r \~/$(IMAGE)-$(MACHINE).tar.bz2
	$(ECHO) "Powering target on"
	@$(VLMTOOL) turnOn -t $(VLM_ID)

vlm-restart: vlm-check-id
	$(ECHO) -n "Checking target is reserved..."
	@status=$$($(VLMTOOL) findMine | grep $(VLM_ID)) ;\
	if [ "$$status" != "$(VLM_ID)" ]; then \
		echo " ooops it wasn't. bailing out." ;\
		exit 1 ;\
	fi
	$(ECHO) " OK";
	$(ECHO) "Restarting target"
	@$(VLMTOOL) reboot -t $(VLM_ID)
#@$(VLMTOOL) turnOn -t $(VLM_ID)
