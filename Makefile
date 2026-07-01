include config.mk

.PHONY: all driver app clean clean-driver clean-app

all: driver app

driver:
	$(MAKE) -C board/driver

app:
	$(MAKE) -C apps

clean: clean-driver clean-app

clean-driver:
	$(MAKE) -C board/driver clean

clean-app:
	$(MAKE) -C apps clean
