variable qcow_source {
  description = "source qcow2 image used for boot vm's"
  type        = string
  default     = "boot.qcow2"
}

# No pets! I'm assuming /tmp gets nuked on each boot
variable base_dir {
  description = "directory path to use for libvirt pools"
  type        = string
  default     = "/tmp"
}

output "variables" {
  value = {
    "qcow_source" = var.qcow_source
    "base_dir"    = var.base_dir
  }
}

variable microos_source {
  description = "where to go to get the qcow2 to boot"
  type        = string
  default     = "http://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-OpenStack-Cloud.qcow2"
}

resource "shell_script" "qcow" {
  lifecycle_commands {
    delete = "${path.root}/qcow.sh delete ${path.root}/${var.qcow_source} ${var.microos_source}"
    create = "${path.root}/qcow.sh create ${path.root}/${var.qcow_source} ${var.microos_source}"
    update = "${path.root}/qcow.sh update ${path.root}/${var.qcow_source} ${var.microos_source}"
    read   = "${path.root}/qcow.sh read ${path.root}/${var.qcow_source} ${var.microos_source}"
  }
}

resource "random_id" "instance" {
  byte_length = 8
}

# total address spaces for a /16 for the /8 we're in.
resource "random_integer" "octets" {
  min  = 1
  max  = 65535
  seed = local.seed
}

output "random_integer" {
  value = {
    "octets" = random_integer.octets.result
  }
}

# instantiate the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "kiwi" {
  # TODO: How do I do something like trigger in null_resource to rebuild the
  # vm and re-run kiwi on the qcow being updated?
  depends_on = [ shell_script.qcow ]
  name       = local.instance
  source     = abspath("${path.root}/${var.qcow_source}")
  pool       = libvirt_pool.kiwi.name
  format     = "qcow2"
}

resource "libvirt_network" "kiwi_net" {
  # the name used by libvirt
  name      = local.instance
  mode      = "nat"
  domain    = "lan"
  addresses = [local.subnet]

  dns {
    enabled    = true
    local_only = true
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

locals {
  seed        = "${abspath(path.root)} ${terraform.workspace}"
  subnet      = cidrsubnet("10.0.0.0/8", 16, random_integer.octets.result)
  instance    = random_id.instance.hex
  ssh_key     = "${abspath(path.root)}/ssh-key-${terraform.workspace}"
  ssh_key_pub = "${local.ssh_key}.pub"
  ssh_config  = "${abspath(path.root)}/ssh-config-${terraform.workspace}"
}

resource "local_file" "ssh_private_key" {
  filename        = local.ssh_key
  file_permission = "0600"
  content         = tls_private_key.ssh_key.private_key_pem
}

resource "local_file" "ssh_public_key" {
  filename        = local.ssh_key_pub
  file_permission = "0600"
  content         = tls_private_key.ssh_key.public_key_openssh
}

# To debug other stuff
output "debug" {
  value = {
    seed     = local.seed
    instance = local.instance
    subnet   = local.subnet
    ssh_key  = local.ssh_key
  }
}

resource "libvirt_pool" "kiwi" {
  name = local.instance
  type = "dir"
  path = abspath("${var.base_dir}/libvirt-${terraform.workspace}-${random_id.instance.hex}")
}

resource "random_pet" "node_petname" {
  separator = "-"
  length    = 3
  prefix    = ""
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  depends_on = [ tls_private_key.ssh_key ]
  name       = "${random_pet.node_petname.id}-cloud-init.iso"
  pool       = libvirt_pool.kiwi.name
  user_data  = templatefile("${path.root}/cloud-config.template", { hostname = random_pet.node_petname.id, authorized_ssh_key = tls_private_key.ssh_key.public_key_openssh })
}

resource "libvirt_domain" "node" {
  name   = random_pet.node_petname.id
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloud_init.id

  network_interface {
    hostname       = random_pet.node_petname.id
    network_id     = libvirt_network.kiwi_net.id
    bridge         = true
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.kiwi.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = "true"
  }

  connection {
    host        = self.network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  # actions to take straight away at first os boot, not in cloud init so we can see output
  provisioner "remote-exec" {
    inline = [
      "touch /tmp/rebooted",
      "transactional-update -n pkg install -n python3-kiwi jing gfxboot checkmedia syslinux git"
    ]
  }

  # note reboots break in terraform cause of dumb go ssh library used reasons, for the on_failure just continue on like nothing failed after the reboot
  provisioner "remote-exec" {
    inline     = ["reboot"]
    on_failure = continue
  }

  # Give the vm some time to reboot before the next provisioner tries to run
  provisioner "local-exec" {
    command = "sleep 10"
  }

  # Fail if we still find our /tmp file, means our reboot never happened, this build is broken
  provisioner "remote-exec" {
    inline = [ "[ ! -f /tmp/rebooted ]" ]
  }
}

locals {
  hosts = {
    "${libvirt_domain.node.name}" = libvirt_domain.node.network_interface[0].addresses[0]
  }
}

output "hosts" {
  value = local.hosts
}

resource "local_file" "ssh_config" {
  depends_on      = [ libvirt_domain.node, tls_private_key.ssh_key ]
  file_permission = "0600"
  filename        = local.ssh_config
  content         = templatefile("${path.root}/ssh-config.template", { user = "root", ssh_key = local.ssh_key, hosts = local.hosts })
}

resource "null_resource" "kiwi_run" {
  depends_on = [ libvirt_domain.node, tls_private_key.ssh_key ]
  connection {
    host        = libvirt_domain.node.network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [ "rm -fr /var/tmp/kiwi", "install -dm755 /var/tmp/kiwi" ]
  }

  provisioner "file" {
    source      = "config.sh"
    destination = "/var/tmp/kiwi/config.sh"
  }

  provisioner "file" {
    source      = "config.xml"
    destination = "/var/tmp/kiwi/config.xml"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      rm -fr /var/tmp/out
      install -dm755 /var/tmp/out
      kiwi-ng --debug system build --description /var/tmp/kiwi --target-dir /var/tmp/out
      cd /var/tmp/out
      for file in $(find . -name '*.qcow2' -type f); do
        sha256sum $file | tee $file.sha256
      done
      FIN
    ]
  }

  # Its lame that the file provisioner onlly provisions local->remote, so just
  # use rsync to get the qcow2 image we build.
  provisioner "local-exec" {
    command = "rsync -avz --progress -e 'ssh -F ${local.ssh_config}' --exclude '*.raw' --exclude kiwi.result --exclude build root@${libvirt_domain.node.name}:/var/tmp/out ."
  }
}
