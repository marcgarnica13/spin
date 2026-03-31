PREFIX ?= /usr/local
EXTENSION_UUID = spin@gsd.local
EXTENSION_DEST = $(HOME)/.local/share/gnome-shell/extensions/$(EXTENSION_UUID)

.PHONY: install install-cli install-extension uninstall uninstall-cli uninstall-extension

install: install-cli install-extension
	@echo "Next: run 'gnome-extensions enable spin@gsd.local'"

install-cli:
	@mkdir -p $(PREFIX)/bin $(PREFIX)/lib/spin
	@cp bin/spin $(PREFIX)/bin/spin
	@chmod +x $(PREFIX)/bin/spin
	@cp lib/*.sh $(PREFIX)/lib/spin/
	@echo "spin CLI installed to $(PREFIX)/bin/spin"

install-extension:
	@mkdir -p $(EXTENSION_DEST)
	@cp gnome-extension/metadata.json $(EXTENSION_DEST)/
	@cp gnome-extension/extension.js $(EXTENSION_DEST)/
	@echo "Spin extension installed to $(EXTENSION_DEST)"

uninstall: uninstall-cli uninstall-extension
	@echo "Spin uninstalled"

uninstall-cli:
	@rm -f $(PREFIX)/bin/spin
	@rm -rf $(PREFIX)/lib/spin
	@echo "spin CLI uninstalled"

uninstall-extension:
	@rm -rf $(EXTENSION_DEST)
	@echo "Spin extension uninstalled"
