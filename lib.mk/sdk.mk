help:: sdk-help

sdk-help:
	$(ECHO) "\n--- sdk commands ---"
	$(ECHO) " sdk-build                	: builds a sdk"
	$(ECHO) " esdk-build                	: builds a esdk"
	$(ECHO) " sdk-install               	: installs the sdk"
	$(ECHO) " sdk-clean                 	: removes any installed sdk"

TUNE = $(shell cd $(TOP)/build ; source poky/oe-init-build-env >/dev/null ; bitbake -e | grep "TUNE_PKGARCH=" | cut -d "\"" -f 2)
SDK_FILE=$(TOP)/build/build/tmp/deploy/sdk/intel-axxia-indist-glibc-x86_64-$(IMAGE)-$(TUNE)-toolchain-$(AXXIA_REL).sh
SDK_ENV=$(TOP)/build/sdk/environment-setup-$(TUNE)-intelaxxia-linux

sdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk)

esdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk_ext)

sdk-install:
	$(RM) -r $(TOP)/build/sdk
	$(SDK_FILE) -y -d $(TOP)/build/sdk
	$(MAKE) -C $(TOP)/build/sdk/sysroots/$(TUNE)-intelaxxia-linux/usr/src/kernel scripts

sdk-clean:
	$(RM) -r $(TOP)/build/sdk
