.PHONY: help install uninstall test run clean all

PACKAGE_BASENAME:=protonsh
PREFIX ?= /usr
BUILD_DIR ?= build
TARGET_BINARY = $(DESTDIR)$(PREFIX)/bin/protonsh
COMPILED_BINARY = $(BUILD_DIR)/protonsh
COMPILED_STEAMLIB_SH = $(BUILD_DIR)/steamlib
# TARGET_STEAMLIB_AWK = steamlib.awk
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
	@echo "	all: compile the script"
	@echo "	install: install the script as a system binary"
	@echo "	uninstall: remove the script from the system"
	@echo "	test: run unit tests"
	@echo "	run: launch the script without installing it"
	@echo "Available variables:"
	@echo "PREFIX: what prefix to use for the binary installation directory (default: /usr)"
	@echo "DESTDIR: destination directory for package creation"

all: $(COMPILED_BINARY)

install: $(TARGET_BINARY) $(COMPILED_STEAMLIB_SH) $(TARGET_STEAMLIB_AWK)

test:
	$(MAKE) -C src/test

run:
	STEAMLIB=$(STEAMLIB_SH) STEAMAWK=$(STEAMLIB_AWK) bash $(SOURCE_BIN)

$(TARGET_BINARY): $(SOURCE_BIN) $(COMPILED_BINARY)
	install -Dm0755 $(COMPILED_BINARY) $@

$(COMPILED_BINARY): $(SOURCE_BIN) $(COMPILED_STEAMLIB_SH)
	mkdir -p $(BUILD_DIR)
	cp $(SOURCE_BIN) $(COMPILED_BINARY)
	sed -i '/. "$${STEAMLIB}"/r $(COMPILED_STEAMLIB_SH)' $(COMPILED_BINARY)
	sed -i '/. "$${STEAMLIB}"/a #EMBEDDED: $(STEAMLIB_SH)' $(COMPILED_BINARY)
	sed -i '/. "$${STEAMLIB}"/d' $(COMPILED_BINARY)
	$(call cleanup_shellcheck,$@)

$(COMPILED_STEAMLIB_SH): $(STEAMLIB_SH) $(STEAMLIB_AWK)
	mkdir -p $(BUILD_DIR)
	cp $(STEAMLIB_SH) $(COMPILED_STEAMLIB_SH)
	# prepare wrapper function with heredoc...
	sed -i '2 a #EMBEDDED: $(STEAMLIB_AWK) file\
embedded_$(notdir STEAMLIB_AWK)()\
{\
	cat << \\EOF\
EOF\
}' $(COMPILED_STEAMLIB_SH)
	# copy file contents from line 5 of original shell script
	sed -i '5r $(STEAMLIB_AWK)' $(COMPILED_STEAMLIB_SH)
	# change the line where the script was called
	sed -i 's/\(awk.*-f \)"$${STEAMAWK}"\(.*\)$$/embedded_$(notdir STEAMLIB_AWK) | \1 - \2/g' $(COMPILED_STEAMLIB_SH)
	# remove shebang
	sed -i 1d $(COMPILED_STEAMLIB_SH)
	$(call cleanup_shellcheck,$(COMPILED_STEAMLIB_SH))

$(TARGET_STEAMLIB_AWK): $(STEAMLIB_AWK)
	install -Dm0644 $< $@

clean:
	rm -rf $(BUILD_DIR)

uninstall:
	rm -f $(TARGET_BINARY)