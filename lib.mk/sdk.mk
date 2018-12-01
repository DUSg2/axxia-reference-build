help:: sdk-help

sdk-help:
	$(ECHO) "\n--- sdk commands ---"
	$(ECHO) " sdk                       : builds a sdk"
	$(ECHO) " esdk                      : builds a esdk"
	$(ECHO) " sdk-install               : installs the sdk"
	$(ECHO) " sdk-clean                 : removes any installed sdk"

SDK_FILE=$(TOP)/build/build/tmp-glibc/deploy/sdk/wrlinux-*-glibc-x86_64-axxiax86_64-wrlinux-image-glibc-std-sdk.sh
SDK_ENV=$(TOP)/build/sdk/environment-setup-core2-64-wrs-linux

sdk: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk)

esdk: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk_ext)

sdk-install:
	$(SDK_FILE) -y -d $(TOP)/build/sdk
	$(MAKE) -C $(TOP)/build/sdk/sysroots/core2-64-wrs-linux/usr/src/kernel scripts

sdk-clean:
	$(RM) -r $(TOP)/build/sdk
