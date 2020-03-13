.PHONY: help install uninstall

PREFIX ?= /usr
TARGET_BINARY = $(DESTDIR)$(PREFIX)/bin/protonsh
SOURCE = protonsh.sh

help:
	@echo "Available targets:"
	@echo "	install: install the script as a system binary"
	@echo "	uninstall: remove the script from the system"
	@echo "Available variables:"
	@echo "PREFIX: what prefix to use for the binary installation directory (default: /usr)"
	@echo "DESTDIR: destination directory for package creation"

install: $(TARGET_BINARY)

$(TARGET_BINARY): $(SOURCE)
	install -Dm0755 $(SOURCE) $(TARGET_BINARY)

uninstall:
	rm -f $(TARGET_BINARY)