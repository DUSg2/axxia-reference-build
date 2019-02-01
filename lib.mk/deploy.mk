TUXLAB=arn-tuxlab.wrs.com
VLMTOOL=ssh $(TUXLAB) /folk/vlm/commandline/vlmTool

help:: deploy.help

deploy.help:
	$(ECHO) "\n--- deploy ---"
	$(ECHO) " TARGET                    	: Target is setup to be $(TARGET)"
	$(ECHO) " deploy.vlm                	: deploys to a reserved VLM target"
	$(ECHO) " deploy.sshkeys            	: add sshkeys to target (not needed for ase-sim)"

deploy.vlm: vlm-check-id
	$(ECHO) -n "Checking target is reserved..."
	@status=$$($(VLMTOOL) findMine | grep $(VLM_ID)) ;\
	if [ "$$status" != "$(VLM_ID)" ]; then \
		echo " ooops it wasn't. bailing out." ;\
		exit 1 ;\
	fi
	$(ECHO) " OK";
	$(ECHO) "Powering target off"
	@$(VLMTOOL) turnOff -t $(VLM_ID)
	$(ECHO) "Transfering kernel to vlm server"
	@scp $(TOP)/build/build/tmp-glibc/deploy/images/$(MACHINE)/bzImage $(TUXLAB):
	$(ECHO) "Transfering rootfs to vlm server"
	@scp $(TOP)/build/build/tmp-glibc/deploy/images/$(MACHINE)/$(IMAGE)-$(MACHINE).tar.bz2 $(TUXLAB):
	$(ECHO) "Setting up VLM with new kernel/rootfs"
	@$(VLMTOOL) copyFile -t $(VLM_ID) -k \~/bzImage -r \~/$(IMAGE)-$(MACHINE).tar.bz2
	$(ECHO) "Powering target on"
	@$(VLMTOOL) turnOn -t $(VLM_ID)
	
deploy.sshkeys:
	$(SSHPASS) -p root ssh-copy-id $(SSH_TARGET)
