TERRAFORM:=terraform
TFOPTS:=
QCOW2:=$(shell terraform appy -target=output.qcow-source > /dev/null  2>&1 && terraform output qcow_source)

.DEFAULT: all

all: $(QCOW2) up

.PHONY: redo
redo: down up

.terraform: providers.tf
	$(TERRAFORM) init

# Build the default qcow if its missing.
$(QCOW2):
	$(MAKE) -C kiwi

.PHONY: up
up: .terraform
	$(TERRAFORM) apply $(TFOPTS) -auto-approve

.PHONY: down
down: .terraform
	$(TERRAFORM) destroy $(TFOPTS) -auto-approve

.PHONY: clean
clean:
	-rm -fr ssh-config-* ssh-key-*

# make it easy to taint/redeploy k8s stuff, mostly for testing.
.PHONY: k8s
k8s:
	idx=`$(TERRAFORM) output -json variables | jq -r '.node_count'`; \
  until [ "$$idx" -eq 0 ]; do \
	  idx=$$((idx-1)); \
    $(TERRAFORM) taint null_resource.k8s_files[$$idx]; \
    $(TERRAFORM) taint null_resource.k8s_pre[$$idx]; \
    $(TERRAFORM) taint null_resource.k8s_install[$$idx]; \
    $(TERRAFORM) taint null_resource.k8s_post[$$idx]; \
	done

# make it easy to taint/redeploy zypper stuff as well
.PHONY: zypper
zypper:
	$(TERRAFORM) taint null_resource.zypper_repos[0]
