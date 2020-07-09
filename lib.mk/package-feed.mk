# set defaults in case they are not defined in hostconfig-*.mk

PKG_FEED_KEYDIR ?= /opt/rpm-repos/gpg-keyring
PKG_FEED_KEY ?= EBC67B2E
PKG_FEED_KEYPASS ?= windriver
PKG_FEED_REPO_URL ?= http://128.224.95.179:7777
PKG_FEED_TARGET_DIR ?= /opt/rpm-repos/public/rpms

# local variables
PKG_FEED_SOURCE_DIR = $(TOP)/build/build/tmp-glibc/work/axxiax86_64-wrs-linux/$(IMAGE)/1.0-r5/oe-rootfs-repo/
LOCAL_CONF = $(TOP)/build/build/conf/local.conf

WRLINUX_VERSION_FILE = $(TOP)/build/layers/wrlinux/conf/wrlinux-version.inc
MAJOR_VER=$(shell grep -m 1 WRLINUX_MAJOR_VERSION $(WRLINUX_VERSION_FILE) | cut -d'"' -f2)
YEAR_VER=$(shell grep -m 1 WRLINUX_YEAR_VERSION $(WRLINUX_VERSION_FILE) | cut -d'"' -f2)
WW_VER=$(shell grep -m 1 WRLINUX_WW_VERSION $(WRLINUX_VERSION_FILE) | cut -d'"' -f2)
UPDATE_VER=$(shell grep -m 1 WRLINUX_UPDATE_VERSION $(WRLINUX_VERSION_FILE) | cut -d'"' -f2)
PKG_FEED_DISTRO_VERSION=$(MAJOR_VER).$(YEAR_VER).$(WW_VER).$(UPDATE_VER)

define setup-package-feed
	echo "INHERIT += \" buildhistory\"" >> $(LOCAL_CONF) ; \
	echo "BUILDHISTORY_COMMIT = \"1\"" >> $(LOCAL_CONF) ; \
	echo "PRSERV_HOST = \"localhost:0\"" >> $(LOCAL_CONF) ; \
	echo "EXTRA_IMAGE_FEATURES += \" package-management\"" >> $(LOCAL_CONF) ; \
	if [ "$(ENABLE_PACKAGE_FEED_SIGN)" = "yes" ]; then \
		echo "INHERIT += \" sign_rpm\"" >> $(LOCAL_CONF) ; \
		echo "GPG_PATH = \"$(PKG_FEED_KEYDIR)\"" >> $(LOCAL_CONF) ; \
		echo "RPM_GPG_NAME = \"$(PKG_FEED_KEY)\"" >> $(LOCAL_CONF) ; \
		echo "RPM_GPG_PASSPHRASE = \"$(PKG_FEED_KEYPASS)\"" >> $(LOCAL_CONF) ; \
		echo "INHERIT += \" sign_package_feed\"" >> $(LOCAL_CONF) ; \
		echo "PACKAGE_FEED_GPG_NAME = \"$(PKG_FEED_KEY)\"" >> $(LOCAL_CONF) ; \
		echo "PACKAGE_FEED_GPG_PASSPHRASE_FILE = \"$(PKG_FEED_KEYDIR)/passphrase-package-feed.txt\"" >> $(LOCAL_CONF) ; \
	fi; \
	echo "PACKAGE_FEED_URIS = \"$(PKG_FEED_REPO_URL)\"" >> $(LOCAL_CONF) ; \
	echo "PACKAGE_FEED_BASE_PATHS = \"rpms/\$${DISTRO}/\$${DISTRO_VERSION}/\$${MACHINE}\"" >> $(LOCAL_CONF) ; \
	echo "DISTRO_CODENAME = \"$(PROJECT_CODENAME)\"" >> $(LOCAL_CONF)
endef

package-feed-deploy:
	$(Q)if [ "$(ENABLE_PACKAGE_FEED)" = "yes" ]; then \
		echo -n "Deploying package feed to $(PKG_FEED_TARGET_DIR)/$(DISTRO)/$(PKG_FEED_DISTRO_VERSION)/$(MACHINE)... "; \
		mkdir -p $(PKG_FEED_TARGET_DIR)/$(DISTRO)/$(PKG_FEED_DISTRO_VERSION)/$(MACHINE); \
		rsync -r -u $(PKG_FEED_SOURCE_DIR)/ $(PKG_FEED_TARGET_DIR)/$(DISTRO)/$(PKG_FEED_DISTRO_VERSION)/$(MACHINE); \
		echo "Done."; \
	fi
