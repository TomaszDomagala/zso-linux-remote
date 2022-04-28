all: help

ROOT_DIR=$(shell pwd)
LINUX_DIR=source
LINUX_VERSION=linux-5.16.5

.PHONY: copy-config
copy-config: ## copy config to linux dir
	@echo "Copying config files..."
	@cp $(ROOT_DIR)/config $(ROOT_DIR)/$(LINUX_DIR)/.config
	@cd $(ROOT_DIR)/$(LINUX_DIR) && make oldconfig

.PHONY: compile-kernel
compile-kernel: ## compile kernel
	@echo "Compiling kernel..."
	@cd $(ROOT_DIR)/$(LINUX_DIR) && make -j8

.PHONY: upload-kernel
upload-kernel: ## copies kernel to the vm
	@echo "Uploading kernel to the vm..."
	@rsync -arvz -rsh=ssh -e 'ssh -p 2222' $(LINUX_DIR) root@localhost:/root

.PHONY: install-kernel
install-kernel: ## installs kernel on the vm
	@echo "Installing kernel on the vm..."
	@ssh -p 2222 root@localhost "cd ~/$(LINUX_DIR) && make modules_install -j8"
	@ssh -p 2222 root@localhost "cd ~/$(LINUX_DIR) && make prepare -j8"
	@ssh -p 2222 root@localhost "cd ~/$(LINUX_DIR) && make install -j8"

.PHONY: test-kernel
test-kernel: ## test kernel
	@echo "Uploading test to the vm..."
	@rsync -ar -rsh=ssh -e 'ssh -p 2222' $(ROOT_DIR)/test root@localhost:/root
	@echo "Running test on the vm..."
	@ssh -p 2222 root@localhost "cd ~/test && make clean && make"

original-source.tar.gz:
	@echo "Downloading original source..."
	@wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v5.x/$(LINUX_VERSION).tar.gz

original-source: original-source.tar.gz
	@echo "Extracting original source..."
	@tar -xzf $<
	@mv $(LINUX_VERSION) $@

.PHONY: linux.patch
linux.patch:
	@echo "Creating patch file..."
	-@diff -ruN -x 'tools' -x 'Documentation' -x '.kunitconfig' original-source source > $@

	

.PHONY: deploy
deploy: ## compile, upload and install kernel
	@make compile-kernel
	@make upload-kernel
	@make install-kernel
	@echo "Rebooting vm after timeout..."
	-@ssh -p 2222 root@localhost reboot
	@sleep 7s
	@make test-kernel

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -rf original-source
	@rm -rf original-source.tar.gz
	@cd test && make clean
	@rm linux.patch

.PHONY: help
help:
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {printf "\033[36m%-25s\033[0m %s\n", $$1, $$NF}' $(MAKEFILE_LIST)
