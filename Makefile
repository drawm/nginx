include .make
VAGRANT_BOX ?= ubuntu/trusty64
TEST_PLAYBOOK ?= test.yml

.DEFAULT_GOAL := help
.PHONY: help

export VAGRANT_BOX

all: test vagrant_halt clean

## Run tests on any file change
watch: test_deps
	while sleep 1; do \
		find defaults/ meta/ tasks/ templates/ tests/test.yml tests/Vagrantfile \
		| entr -d make lint vagrant; \
	done

## Run tests
test: test_deps lint vagrant

## ! Executes Ansible tests using local connection
# run it ONLY from within a test VM.
# Example: make test_ansible
#          make test_ansible TEST_PLAYBOOK=test-something-else.yml
test_ansible: test_ansible_build test_ansible_configure
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags assert \
		$(TEST_PLAYBOOK)

## ! Executes Ansible tests using local connection
# run it ONLY from witinh a test VM.
# Example: make test_ansible_build
#          make test_ansible_build TEST_PLAYBOOK=test-something-else.yml
test_ansible_%:
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags=$(subst test_ansible_,,$@) \
		$(TEST_PLAYBOOK)
	cd tests && ansible-playbook \
		--inventory inventory \
		--connection local \
		--tags=$(subst test_ansible_,,$@) \
		$(TEST_PLAYBOOK) \
		| grep -q 'changed=0.*failed=0' \
			&& (echo 'Idempotence test: pass' && exit 0) \
			|| (echo 'Idempotence test: fail' && exit 1)

## Install test dependencies
test_deps:
	rm -rf tests/sansible.*
	ln -s .. tests/sansible.nginx

## Start and (re)provisiom Vagrant test box
vagrant:
	cd tests && vagrant up --no-provision
	cd tests && vagrant provision
	@echo "- - - - - - - - - - - - - - - - - - - - - - -"
	@echo "           Provisioning Successful"
	@echo "- - - - - - - - - - - - - - - - - - - - - - -"

## Execute simple Vagrant command
# Example: make vagrant_ssh
#          make vagrant_halt
vagrant_%:
	cd tests && vagrant $(subst vagrant_,,$@)

## Lint role
# You need to install ansible-lint
lint:
	find defaults/ meta/ tasks/ templates/ -name "*.yml" | xargs -I{} ansible-lint {}

## Clean up
clean:
	rm -rf tests/sansible.*
	cd tests && vagrant destroy -f

## Prints this help
help:
	@awk -v skip=1 \
		'/^##/ { sub(/^[#[:blank:]]*/, "", $$0); doc_h=$$0; doc=""; skip=0; next } \
		 skip  { next } \
		 /^#/  { doc=doc "\n" substr($$0, 2); next } \
		 /:/   { sub(/:.*/, "", $$0); printf "\033[34m%-30s\033[0m\033[1m%s\033[0m %s\n\n", $$0, doc_h, doc; skip=1 }' \
		$(MAKEFILE_LIST)

.make:
	echo "" > .make
