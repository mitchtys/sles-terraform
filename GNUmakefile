TERRAFORM:=terraform

.DEFAULT: all

all: up

.PHONY: redo
redo: down up

.terraform:
	$(TERRAFORM) init

.PHONY: up
up: .terraform
	$(TERRAFORM) apply -auto-approve

.PHONY: down
down:
	$(TERRAFORM) destroy -auto-approve

.PHONY: clean
clean:
	-rm -fr ssh-config-* ssh-key-*
