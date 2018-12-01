
ADK_DIR=$(TOP)/build/adk
ADK_TAR=$(SNR_ADK_DIR)/adk_source*.tar.gz
ADK_SRC=$(ADK_DIR)/adk_source.tiger_netd
ADK_TARGET_DIR=/opt/adk

help:: adk.help

adk.help:
	$(ECHO) "\n--- adk ----"
	$(ECHO) " adk-build-apps            : builds adk examples"
	$(ECHO) " adk-deploy                : deploys adk examples on target in $(ADK_TARGET_DIR)"
	$(ECHO) " adk-clean                 : removes $(ADK_DIR) directory"

adk-fetch:
	$(Q)if [ ! -d $(ADK_SRC) ]; then \
		mkdir -p $(ADK_DIR); \
		tar -xzf $(ADK_TAR) -C $(ADK_DIR); \
	fi;

adk-build-apps: adk-fetch
	$(Q)if [ ! -f $(SDK_ENV) ]; then \
		echo 'SDK is not installed. Run first "make sdk-install" command.'; \
	        exit 1; \
	fi;
	$(CD) $(ADK_SRC); \
	source $(SDK_ENV) ; \
	export ADK_NETD_ROOT=$(ADK_SRC); \
	make -s -C apps;
	$(RM) -r $(ADK_SRC)/build;
	$(MKDIR) $(ADK_SRC)/build; 
	$(FIND) $(ADK_SRC)/apps -type f -executable -exec cp {} $(ADK_SRC)/build \;

adk-deploy:
	$(ECHO) "ADK examples are installed on $(TARGET) in $(ADK_TARGET_DIR) directory."
	$(SSH_CMD) -- "mkdir -p $(ADK_TARGET_DIR)"
	$(SCP_CMD)  $(ADK_SRC)/build/*  $(SSH_TARGET):$(ADK_TARGET_DIR)
	$(SCP_CMD)  $(TOP)/lib.mk/adk-test.sh $(SSH_TARGET):$(ADK_TARGET_DIR)

adk-clean:
	$(RM) -r $(ADK_DIR)
