.PHONY: help install uninstall test

PACKAGE_BASENAME:=protonsh
PREFIX ?= /usr
TARGET_BINARY = $(DESTDIR)$(PREFIX)/bin/protonsh
TARGET_STEAMLIB_SH = $(DESTDIR)$(PREFIX)/share/$(PACKAGE_BASENAME)/steamlib
TARGET_STEAMLIB_AWK = $(DESTDIR)$(PREFIX)/share/$(PACKAGE_BASENAME)/steamlib.awk
SOURCE_BIN = src/bin/protonsh.sh
STEAMLIB_SH = src/fun/steamlib.sh
STEAMLIB_AWK = src/fun/steamlib.awk

# Hardcode variable with the given value in file.
# Arguments:
# $(1) - variable name to hardcode
# $(2) - value to hardcode in $(1)
# $(3) - file where the substitution takes place
define harden_variable_with_val
	sed -i 's#$${$(1):-.*}#$(2)#g' $(3)
endef

# Hardcode variable with the default value in file.
# Arguments:
# $(1) - variable name to hardcode
# $(2) - file where the substitution takes place
define harden_variable
	sed -i 's#$${$(1):-\(.*\)}#\1#g' $(2)
endef

# Remove any shellcheck-related comments.
# Arguments:
# ($1) - file that needs to be cleaned up
define cleanup_shellcheck
	sed -i '/# shellcheck source=/d' $(1)
endef

help:
	@echo "Available targets:"
	@echo "	install: install the script as a system binary"
	@echo "	uninstall: remove the script from the system"
	@echo "Available variables:"
	@echo "PREFIX: what prefix to use for the binary installation directory (default: /usr)"
	@echo "DESTDIR: destination directory for package creation"

install: $(TARGET_BINARY) $(TARGET_STEAMLIB_SH) $(TARGET_STEAMLIB_AWK)

test:
	$(MAKE) -C src/test

$(TARGET_BINARY): $(SOURCE_BIN)
	install -Dm0755 $< $@
	$(call harden_variable,STEAMLIB,$@)
	$(call cleanup_shellcheck,$@)

$(TARGET_STEAMLIB_SH): $(STEAMLIB_SH)
	install -Dm0644 $< $@
	$(call harden_variable,STEAMAWK,$@)
	$(call cleanup_shellcheck,$@)

$(TARGET_STEAMLIB_AWK): $(STEAMLIB_AWK)
	install -Dm0644 $< $@

uninstall:
	rm -f $(TARGET_BINARY)