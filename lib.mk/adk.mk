
ADK_DIR=$(TOP)/build/adk
ADK_TAR=$(REF_ASE_BASE)/adk_source*.tar.gz
ADK_SRC=$(ADK_DIR)/adk_source.tiger_netd

help:: adk.help

adk.help:
	$(ECHO) "\n--- adk ----"
	$(ECHO) " adk-build-apps            : builds adk"
	$(ECHO) " adk-clean                 : removes $(ADK_DIR) directory"

adk-fetch:
	$(Q)if [ ! -d $(ADK_SRC) ]; then \
		mkdir -p $(ADK_DIR); \
		tar -xzf $(ADK_TAR) -C $(ADK_DIR); \
	fi;

adk-build-apps: adk-fetch
	$(CD) $(ADK_SRC); \
	source $(TOP)/build/sdk/environment-setup-core2-64-intelaxxia-linux ; \
	export ADK_NETD_ROOT=$(ADK_SRC); \
	make -C apps; 

adk-clean:
	$(RM) -r $(ADK_DIR)
