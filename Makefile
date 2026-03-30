PREFIX ?= /usr/local

.PHONY: install uninstall

install:
	@mkdir -p $(PREFIX)/bin $(PREFIX)/lib/spin
	@cp bin/spin $(PREFIX)/bin/spin
	@chmod +x $(PREFIX)/bin/spin
	@cp lib/*.sh $(PREFIX)/lib/spin/
	@echo "spin installed to $(PREFIX)/bin/spin"

uninstall:
	@rm -f $(PREFIX)/bin/spin
	@rm -rf $(PREFIX)/lib/spin
	@echo "spin uninstalled"
