# Reference build of Axxia deliveries
#
# Author : Per Hallsmark <per.hallsmark@windriver.com>
# Repo   : https://github.com/saxofon/axxia-reference-build
#
#

TOP 		?= $(shell pwd)
SHELL		?= /bin/bash

-include $(TOP)/lib.mk/tools.mk

POKY_URL = git://git.yoctoproject.org/poky.git
POKY_REL = 90414ecd5cf72995074f3dc6b05cfbee0a1dab67

OE_URL = https://github.com/openembedded/meta-openembedded.git
OE_REL = 352531015014d1957d6444d114f4451e241c4d23
LAYERS += $(TOP)/build/layers/meta-openembedded
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-oe
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-python
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-networking
LAYERS += $(TOP)/build/layers/meta-openembedded/meta-filesystems

VIRT_URL = git://git.yoctoproject.org/meta-virtualization
VIRT_REL = bd77388f31929f38e7d4cc9c711f0f83f563007e
LAYERS += $(TOP)/build/layers/meta-virtualization

INTEL_URL=git://git.yoctoproject.org/meta-intel
INTEL_REL=f66ce51d059d291a441d896854be8db70de5a554
LAYERS += $(TOP)/build/layers/meta-intel

REL_NR=15
SNR_BASE=/wr/installs/ASE/snowridge/$(REL_NR)
ASE_BASE=$(SNR_BASE)

AXXIA_URL=git@github.com:axxia/meta-intel-axxia_private.git
AXXIA_REL=snr_delivery$(REL_NR)
LAYERS += $(TOP)/build/layers/meta-intel-axxia/meta-intel-snr
LAYERS += $(TOP)/build/layers/meta-intel-axxia

ENABLE_AXXIA_RDK=yes
ifeq ($(ENABLE_AXXIA_RDK),yes)

LAYERS += $(TOP)/build/layers/meta-dpdk
DPDK_URL=https://git.yoctoproject.org/cgit/cgit.cgi/meta-dpdk
DPDK_REL=9d2d7a606278131479cc5b6c8cad65ddea3ff9f6
AXXIA_RDK_DPDKPATCH=$(SNR_BASE)/dpdk_diff*.patch

LAYERS += $(TOP)/build/layers/meta-intel-axxia-rdk
AXXIA_RDK_URL=git@github.com:axxia/meta-intel-axxia-rdk.git
AXXIA_RDK_KLM=$(SNR_BASE)/rdk_klm_src_*xz
AXXIA_RDK_USER=$(SNR_BASE)/rdk_user_src_*xz

AXXIA_ADK_LAYER=$(SNR_BASE)/adk_meta-intel-axxia-adknetd*
AXXIA_ADK_SOURCE=$(SNR_BASE)/adk_source*
LAYERS += $(TOP)/build/layers/meta-intel-axxia-adknetd

endif

SDK_FILE=$(TOP)/build/build/tmp/deploy/sdk/intel-axxia-indist-glibc-x86_64-axxia-image-sim*.sh
AXXIA_RDK_SAMPLES=$(SNR_BASE)/samples/snr

MACHINE=axxiax86-64

IMAGE=axxia-image-sim

define bitbake
	cd build ; \
	source poky/oe-init-build-env ; \
	bitbake $(1)
endef

define bitbake-task
	cd build ; \
	source poky/oe-init-build-env ; \
	bitbake $(1) -c $(2)
endef

all: help

help::
	$(ECHO) "Current useful make targets"
	$(ECHO) "======================================================="
	$(ECHO) "\n--- build commands ---"
	$(ECHO) " fs                     : builds a platform"
	$(ECHO) " sdk                       : builds a sdk"
	$(ECHO) " esdk                      : builds a esdk"
	$(ECHO) " install-sdk               : installs the sdk"
	$(ECHO) " clean                     : removes any platform build, sample compile or sdk install"
	$(ECHO) " distclean                 : remove $(TOP)/build directory"

-include $(TOP)/lib.mk/dpdk.mk
-include $(TOP)/lib.mk/ase-sample-datapath.mk
-include $(TOP)/lib.mk/sim-ase.mk

$(TOP)/build/poky:

$(TOP)/build/layers/meta-openembedded:
	git -C $(TOP)/build/layers clone $(OE_URL) $@
	git -C $@ checkout $(OE_REL)

$(TOP)/build/layers/meta-virtualization:
	git -C $(TOP)/build/layers clone $(VIRT_URL) $@
	git -C $@ checkout $(VIRT_REL)

$(TOP)/build/layers/meta-intel:
	git -C $(TOP)/build/layers clone $(INTEL_URL) $@
	git -C $@ checkout $(INTEL_REL)

$(TOP)/build/layers/meta-intel-axxia:
	git -C $(TOP)/build/layers clone $(AXXIA_URL) $@
	git -C $@ checkout $(AXXIA_REL)

$(TOP)/build/layers/meta-intel-axxia/meta-intel-snr: $(TOP)/build/layers/meta-intel-axxia

ifeq ($(ENABLE_AXXIA_RDK),yes)
$(TOP)/build/layers/meta-dpdk:
	git -C $(TOP)/build/layers clone $(DPDK_URL) $@
	git -C $@ checkout $(DPDK_REL)

$(TOP)/build/layers/meta-intel-axxia-rdk:
	git -C $(TOP)/build/layers clone $(AXXIA_RDK_URL) $@
	git -C $@ checkout $(AXXIA_REL)
	mkdir -p $@/downloads
	cp $(AXXIA_RDK_KLM) $@/downloads/rdk_klm_src.tar.xz
	cp $(AXXIA_RDK_USER) $@/downloads/rdk_user_src.tar.xz
	cp $(AXXIA_RDK_DPDKPATCH) $@/downloads/dpdk_diff.patch
	mkdir -p $@/downloads/unpacked
	tar -C $@/downloads/unpacked -xf $(AXXIA_RDK_KLM)
	cp $(TOP)/dpdk-rdk_18.05.bb $(TOP)/build/layers/meta-intel-axxia-rdk/recipes-extended/dpdk/

$(TOP)/build/layers/meta-intel-axxia-adknetd:
	tar -xzf $(AXXIA_ADK_LAYER) -C $(TOP)/build/layers
	cp $(AXXIA_ADK_SOURCE) $(TOP)/build/layers/meta-intel-axxia-adknetd/downloads/adk_source.tiger_netd.tar.gz

.PHONY: extract-rdk-patches
extract-rdk-patches:
	mkdir -p $(TOP)/build/extracted-rdk-patches
	git -C build/build/tmp/work-shared/axxiax86-64/kernel-source format-patch -o $(TOP)/build/extracted-rdk-patches before_rdk_commits..after_rdk_commits
endif

# create wrlinux platform
.PHONY: build
build:
	$(Q)if [ ! -d $@ ]; then \
		mkdir -p $@/layers ; \
		cd $@ ; \
		git clone $(POKY_URL) ; \
		git -C poky checkout $(POKY_REL) ; \
	fi

# create bitbake build
.PHONY: build/build
build/build: build $(LAYERS)
	$(Q)if [ ! -d $@ ]; then \
		cd build ; \
		source poky/oe-init-build-env ; \
		$(foreach layer, $(LAYERS), bitbake-layers add-layer $(layer);) \
		sed -i s/^MACHINE.*/MACHINE\ =\ \"$(MACHINE)\"/g conf/local.conf ; \
		echo "DISTRO = \"intel-axxia-indist\"" >> conf/local.conf ; \
		echo "DISTRO_FEATURES_append = \" userspace\"" >> conf/local.conf ; \
		echo "DISTRO_FEATURES_append = \" dpdk\"" >> conf/local.conf ; \
		echo "RUNTARGET = \"simics\"" >> conf/local.conf ; \
		echo "RELEASE_VERSION = \"$(AXXIA_REL)\"" >> conf/local.conf ; \
		echo "PREFERRED_PROVIDER_virtual/kernel = \"linux-yocto\"" >> conf/local.conf ; \
		echo "PREFERRED_VERSION_linux-yocto = \"4.12%\"" >> conf/local.conf ; \
	fi

bbs: build/build
	$(Q)cd build ; \
	source poky/oe-init-build-env ; \
	bash

fs: build/build
	$(call bitbake, $(IMAGE))

sdk: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk)

install-sdk:
	$(SDK_FILE) -y -d $(TOP)/build/sdk

esdk: build/build
	$(call bitbake-task, $(IMAGE), populate_sdk_ext)

clean:
	$(RM) -r build/build

distclean:
	$(RM) -r build
