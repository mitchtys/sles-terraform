TERRAFORM:=terraform

.DEFAULT: all

all: up

.PHONY: redo
redo: down up

.terraform: providers.tf
	$(TERRAFORM) init

.PHONY: up
up: .terraform
	$(TERRAFORM) apply -auto-approve

.PHONY: down
down: .terraform
	$(TERRAFORM) destroy -auto-approve

.PHONY: clean
clean:
	-rm -fr out ssh-config-* ssh-key-*

.PHONY: kiwi
kiwi:
	-$(TERRAFORM) taint 'null_resource.kiwi_run'
	$(MAKE) up
