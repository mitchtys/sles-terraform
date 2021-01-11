# Mark that this configuration has only been tested on 0.12.28+ and not 0.13
terraform {
  required_version = "> 0.12.28, < 0.13"
  required_providers {
    local =  "1.4.0"
    null = "2.1.2"
    random = "2.2.1"
  }
}
provider "tls" {}
provider "template" {}

# Note uses this as well
# https://registry.terraform.io/providers/scottwinkler/shell/latest
# https://github.com/dmacvicar/terraform-provider-libvirt#installing
# instantiate the libvirt provider if in use
provider "libvirt" {
  uri = "qemu:///system"
}
