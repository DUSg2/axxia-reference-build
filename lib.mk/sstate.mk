# sstate.mk

SSTATE_LOCAL_DIR    ?=$(TOP)/build/build/sstate-cache

help:: sstate.help

sstate.help:
	$(ECHO) "\n--- sstate ---"
	$(ECHO) "sstate-deploy             : deploys local sstate to $(SSTATE_MIRROR)"

sstate-deploy:
ifdef SSTATE_MIRROR_DIR
	$(FIND) $(SSTATE_LOCAL_DIR) -type l -delete
	$(FIND) $(SSTATE_LOCAL_DIR) -type f -name "*.done" -delete
	$(CHMOD) -R g-w $(SSTATE_LOCAL_DIR)
	$(CP) -a $(SSTATE_LOCAL_DIR)/* $(SSTATE_MIRROR_DIR)
else
	$(error SSTATE_MIRROR_DIR is not defined)
endif
