help:: sdk-help

sdk-help:
	$(ECHO) "\n--- sdk commands ---"
	$(ECHO) " sdk-build                	: builds a sdk"
	$(ECHO) " esdk-build                	: builds a esdk"
	$(ECHO) " sdk-install               	: installs the sdk"
	$(ECHO) " sdk-clean                 	: removes any installed sdk"

SDK_FILE=$(TOP)/build/build/tmp/deploy/sdk/intel-axxia-indist-glibc-x86_64-$(IMAGE)-core2-64-toolchain-$(AXXIA_REL).sh
SDK_ENV=$(TOP)/build/sdk/environment-setup-core2-64-intelaxxia-linux

sdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk)

esdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk_ext)

sdk-install:
	$(RM) -r $(TOP)/build/sdk
	$(SDK_FILE) -y -d $(TOP)/build/sdk
	$(MAKE) -C $(TOP)/build/sdk/sysroots/core2-64-intelaxxia-linux/usr/src/kernel scripts

sdk-clean:
	$(RM) -r $(TOP)/build/sdk
