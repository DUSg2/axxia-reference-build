help:: sdk-help

sdk-help:
	$(ECHO) "\n--- sdk commands ---"
	$(ECHO) " sdk-build                	: builds a sdk"
	$(ECHO) " esdk-build                	: builds a esdk"
	$(ECHO) " sdk-install               	: installs the sdk"
	$(ECHO) " sdk-clean                 	: removes any installed sdk"

SDK_FILE=$(WRL_BUILD_DEPLOY_DIR)/sdk/intel-axxia-glibc-x86_64-axxia-image-vcn-snr-64-toolchain-$(AXXIA_REL).sh
SDK_ENV=$(TOP)/build/sdk/environment-setup-snr-64-intelaxxia-linux

sdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk)

esdk-build: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk_ext)

sdk-install:
	$(SDK_FILE) -y -d $(TOP)/build/sdk
	$(MAKE) -C $(TOP)/build/sdk/sysroots/snr-64-intelaxxia-linux/usr/src/kernel scripts tools/objtool

sdk-clean:
	$(RM) -r $(TOP)/build/sdk
