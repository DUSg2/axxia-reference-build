TUXLAB=arn-tuxlab.wrs.com
VLMTOOL=ssh $(USER)@$(TUXLAB) /folk/vlm/commandline/vlmTool
WRL_BUILD_DEPLOY_DIR = $(BUILD_DIR)/build/tmp/deploy

ifeq ($(SNR_RELEASE),)
ROOTFS_IMG = $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).tar.bz2
KERNEL_IMG = $(WRL_BUILD_DEPLOY_DIR)/images/$(MACHINE)/bzImage
else
ROOTFS_IMG = $(SNR_REL_DIR)/$(SNR_RELEASE)/$(IMAGE)-$(MACHINE).tar.bz2
KERNEL_IMG = $(SNR_REL_DIR)/$(SNR_RELEASE)/bzImage
endif

help:: deploy.help

deploy.help:
	$(ECHO) "\n--- deploy ---"
	$(ECHO) " TARGET                    	: Target is setup to be $(TARGET)"
	$(ECHO) " deploy.vlm                	: deploys to a reserved VLM target (default on USB rootfs)"
	$(ECHO) " deploy.vlm.usb                : deploys to a reserved VLM target (boot from USB)"
	$(ECHO) " deploy.vlm.nfs                : deploys to a reserved VLM target (boot from NFS)"
	$(ECHO) " deploy.sshkeys            	: add sshkeys to target (not needed for ase-sim)"

deploy.toggleusbdiskroot:
	$(Q) TGT_MAC=`$(VLMTOOL) getAttr -t $(VLM_ID) all | grep ^MAC | awk '{print $$4}' |sed 's/:/-/g'`; \
	CRT=`ssh $(USER)@$(TUXLAB) "cat /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC | grep \"^default pxeboot\" | cut -d'+' -f2"`; \
	if [ "$$CRT" = "sda2" ]; then NEW=sda3; else NEW=sda2; fi; \
	ssh $(USER)@$(TUXLAB) "cp /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC /tmp/01-$$TGT_MAC; \
	sed -i 's\default pxeboot+$$CRT\default pxeboot+$$NEW\g' /tmp/01-$$TGT_MAC; \
	cp /tmp/01-$$TGT_MAC /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC; rm -f /tmp/01-$$TGT_MAC"
	
deploy.togglenfsroot:
	$(Q) TGT_MAC=`$(VLMTOOL) getAttr -t $(VLM_ID) all | grep ^MAC | awk '{print $$4}' |sed 's/:/-/g'`; \
	CRT=`ssh $(USER)@$(TUXLAB) "cat /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC | grep \"^default pxeboot\" | cut -d'+' -f2"`; \
	ssh $(USER)@$(TUXLAB) "cp /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC /tmp/01-$$TGT_MAC; \
	sed -i 's\default pxeboot+$$CRT\default pxeboot+nfsroot\g' /tmp/01-$$TGT_MAC; \
	cp /tmp/01-$$TGT_MAC /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC; rm -f /tmp/01-$$TGT_MAC"

deploy.kernel:
	$(ECHO) "Transfering kernel to vlm server"
	$(Q) scp $(KERNEL_IMG) $(USER)@$(TUXLAB):

deploy.nfsrootfs:
	$(ECHO) "Transfering rootfs to vlm server"
	$(Q)scp $(ROOTFS_IMG) $(USER)@$(TUXLAB):

deploy.usbrootfs:
	$(ECHO) "Transfering USB rootfs to target"
	ssh-keygen -R $(SSH_IP) 1>/dev/null 2>&1
	scp -o "StrictHostKeyChecking no" -P $(SSH_PORT) $(ROOTFS_IMG) root@$(SSH_IP):
	$(ECHO) "Unpack rootfs to USB partition"
	$(Q) TGT_MAC=`$(VLMTOOL) getAttr -t $(VLM_ID) all | grep ^MAC | awk '{print $$4}' |sed 's/:/-/g'`; \
	CRT=`ssh $(USER)@$(TUXLAB) "cat /export/pxeboot/efi64/pxelinux.cfg/01-$$TGT_MAC | grep \"^default pxeboot\" | cut -d'+' -f2"`; \
	if [ "$$CRT" = "sda2" ]; then NEW=sda3; else NEW=sda2; fi; \
	ssh -p $(SSH_PORT) root@$(SSH_IP) "mkdir -p /mnt/rfs; mount /dev/$$NEW /mnt/rfs; rm -rf /mnt/rfs/*; tar -C /mnt/rfs -xjSf /root/$(IMAGE)-$(MACHINE).tar.bz2; umount /mnt/rfs;"

deploy.vlm.usb: vlm-check-reserved
	$(MAKE) deploy.kernel
	$(MAKE) deploy.usbrootfs
	$(ECHO) "Toggle target usbdiskroot"	
	$(MAKE) deploy.toggleusbdiskroot
	$(ECHO) "Powering target off"
	$(Q)$(VLMTOOL) turnOff -t $(VLM_ID)
	$(ECHO) "Setting up VLM with new kernel/rootfs"
	$(Q)$(VLMTOOL) copyFile -t $(VLM_ID) -k \~/bzImage
	$(ECHO) "Powering target on"
	$(Q)$(VLMTOOL) turnOn -t $(VLM_ID)

deploy.vlm.nfs: vlm-check-reserved
	$(ECHO) "Powering target off"
	$(Q)$(VLMTOOL) turnOff -t $(VLM_ID)
	$(MAKE) deploy.kernel
	$(MAKE) deploy.nfsrootfs
	$(ECHO) "Setting up VLM with new kernel/rootfs"
	$(Q)$(VLMTOOL) copyFile -t $(VLM_ID) -k \~/bzImage -r \~/$(IMAGE)-$(MACHINE).tar.bz2
	$(ECHO) "Toggle target nfsroot"	
	$(MAKE) deploy.togglenfsroot
	$(ECHO) "Powering target on"
	$(Q)$(VLMTOOL) turnOn -t $(VLM_ID)
	
deploy.vlm:
	$(MAKE) deploy.vlm.usb		

deploy.sshkeys:
	$(SSHPASS) -p root ssh-copy-id $(SSH_TARGET)

