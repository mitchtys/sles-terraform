variable with_kiwi_run {
  description = "controls if the kiwi script gets run or not, generally not useful unless you're debugging and want to run kiwi manually"
  type        = bool
  default     = true
}

variable allow_existing_root {
  description = "whether kiwi-ng should have --allow-existing-root to reuse an already built root for images"
  type        = bool
  default     = true
}

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

resource "libvirt_volume" "kiwi" {
  count      = local.count
  # TODO: How do I do something like trigger in null_resource to rebuild the
  # vm and re-run kiwi on the qcow being updated?
  depends_on = [ shell_script.qcow ]
  name       = "${local.instance}-kiwi"
  source     = abspath("${path.root}/${var.qcow_source}")
  pool       = libvirt_pool.kiwi[count.index].name
  format     = "qcow2"
}

resource "libvirt_volume" "srv_kiwi" {
  count      = local.count
  name       = "${local.instance}-srv-kiwi"
  pool       = libvirt_pool.kiwi[count.index].name
  format     = "qcow2"
  # ~60GiB should be enough for caches etc... if not make it bigger and rebuild
  size       = (60*1024*1024*1024)
}

resource "libvirt_network" "kiwi" {
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
  count       = 1 # We're only building one kiwi builder here
  seed        = "${abspath(path.root)} ${terraform.workspace}"
  subnet      = cidrsubnet("10.0.0.0/8", 16, random_integer.octets.result)
  instance    = random_id.instance.hex
  ssh_key     = "${abspath(path.root)}/ssh-key-${terraform.workspace}"
  ssh_key_pub = "${local.ssh_key}.pub"
  ssh_config  = "${abspath(path.root)}/ssh-config-${terraform.workspace}"
  known_hosts = "${abspath(path.root)}/known-hosts-${terraform.workspace}"
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
  count = local.count
  name  = local.instance
  type  = "dir"
  path  = abspath("${var.base_dir}/libvirt-${terraform.workspace}-${random_id.instance.hex}")
}

resource "libvirt_volume" "node" {
  count          = local.count
  name           = "${random_pet.node_petname[count.index].id}.qcow2"
  base_volume_id = libvirt_volume.kiwi[count.index].id
  pool           = libvirt_pool.kiwi[count.index].name
}

resource "random_pet" "node_petname" {
  count     = local.count
  separator = "-"
  length    = 3
  prefix    = ""
}

resource "tls_private_key" "host_key_rsa" {
  count     = local.count
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  depends_on = [
    tls_private_key.ssh_key,
    tls_private_key.host_key_rsa
  ]
  name       = "${random_pet.node_petname[count.index].id}-cloud-init.iso"
  pool       = libvirt_pool.kiwi[count.index].name
  count      = local.count
  user_data  = templatefile("${path.root}/cloud-config.template", {
    hostname = random_pet.node_petname[count.index].id,
    authorized_ssh_key = tls_private_key.ssh_key.private_key_pem,
    authorized_ssh_key_pub = tls_private_key.ssh_key.public_key_openssh,
    host_key_rsa = tls_private_key.host_key_rsa[count.index].private_key_pem,
    host_key_rsa_pub = tls_private_key.host_key_rsa[count.index].public_key_openssh
  })
}

resource "libvirt_domain" "node" {
  name   = random_pet.node_petname[count.index].id
  count  = local.count
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloud_init[count.index].id

  network_interface {
    hostname       = random_pet.node_petname[count.index].id
    network_id     = libvirt_network.kiwi.id
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
    volume_id = element(libvirt_volume.kiwi.*.id, count.index)
  }

  disk {
    volume_id = element(libvirt_volume.srv_kiwi.*.id, count.index)
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

  provisioner "file" {
    source      = "srv-kiwi.automount"
    destination = "/tmp/srv-kiwi.automount"
  }

  provisioner "file" {
    source      = "srv-kiwi.mount"
    destination = "/tmp/srv-kiwi.mount"
  }

  # Setup /dev/vdb as ext3 to /srv/kiwi
  provisioner "remote-exec" {
    inline = [<<FIN
      set -e
      mkfs.ext3 -j /dev/vdb
      install -m644 /tmp/srv-kiwi.automount /etc/systemd/system
      install -m644 /tmp/srv-kiwi.mount /etc/systemd/system
      systemctl daemon-reload
      systemctl enable srv-kiwi.mount
    FIN
    ]
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      set -e
      rm -fr /etc/ssh/ssh_host_dsa_key
      rm -fr /etc/ssh/ssh_host_dsa_key.pub
      rm -fr /etc/ssh/ssh_host_ed25519_key
      rm -fr /etc/ssh/ssh_host_ed25519_key.pub
      rm -fr /etc/ssh/ssh_host_ecdsa_key
      rm -fr /etc/ssh/ssh_host_ecdsa_key.pub
      install -m600 --owner root --group root /etc/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
      install -m644 --owner root --group root /etc/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
      systemctl restart sshd.service
      sleep ${count.index}
      until systemctl is-active --quiet sshd.service; do
        sleep 1
      done
    FIN
    ]
  }

  # actions to take straight away at first os boot, not in cloud init so we can see output
  provisioner "remote-exec" {
    inline = [
      "touch /tmp/rebooted",
      "transactional-update -n pkg install -n python3-kiwi jing gfxboot checkmedia syslinux git"
    ]
  }

  # note reboots break in terraform cause of dumb go ssh library used reasons,
  # for the on_failure just continue on like nothing failed after the reboot
  provisioner "remote-exec" {
    inline     = ["reboot"]
    on_failure = continue
  }

  # Give the vm some time to reboot before the next provisioner tries to run
  provisioner "local-exec" {
    command = "sleep 10"
  }

  # Fail if we still find our /tmp file, means our reboot never happened, this
  # build is broken
  provisioner "remote-exec" {
    inline = [ "set -e; [ ! -f /tmp/rebooted ]" ]
  }
}

locals {
  hosts = {
    for x in libvirt_domain.node:
      x.name => x.network_interface[0].addresses[0]
  }
  host_keys = {
    for i in range(0, local.count):
      random_pet.node_petname[i].id => tls_private_key.host_key_rsa[i].public_key_openssh
  }
}

output "hosts" {
  value = local.hosts
}

output "host_keys" {
  value = local.host_keys
}

resource "local_file" "ssh_config" {
  depends_on      = [ libvirt_domain.node, tls_private_key.ssh_key ]
  file_permission = "0600"
  filename        = local.ssh_config
  content         = templatefile("${path.root}/ssh-config.template", {
    user = "root",
    ssh_key = local.ssh_key,
    hosts = local.hosts
  })
}

resource "local_file" "known_hosts" {
  depends_on      = [
    libvirt_domain.node,
    tls_private_key.host_key_rsa,
  ]
  file_permission = "0644"
  filename        = local.known_hosts
  content = templatefile("${path.root}/known-hosts.template", {
    host_keys = local.host_keys,
    hosts = local.hosts
  })
}

resource "null_resource" "kiwi_run" {
  count      = var.with_kiwi_run ? local.count : 0
  depends_on = [ libvirt_domain.node, tls_private_key.ssh_key ]
  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    source      = "config.sh"
    destination = "/tmp/config.sh"
  }

  provisioner "file" {
    source      = "config.xml"
    destination = "/tmp/config.xml"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      set -xe
      # /tmp is 2g in microos, not enogh when you install a fair amount of rpms
      # So use /srv/kiwi which should be its own mount point with a size we can
      # control.
      export TMPDIR=/srv/kiwi/tmp
      install -Ddm1777 $TMPDIR
      install -m755 /tmp/config.sh /srv/kiwi
      install -m644 /tmp/config.xml /srv/kiwi
      rm -fr /tmp/config.{sh,xml}
      extra=""
      if [ "${var.allow_existing_root}" = "true" ]; then
        extra=" --allow-existing-root "
      else
        rm -fr /srv/kiwi/out
      fi
      install -dm755 /srv/kiwi/out
      kiwi-ng --debug system build $extra --description /srv/kiwi --target-dir /srv/kiwi/out
      cd /srv/kiwi/out
      for file in $(find . -name '*.qcow2' -type f); do
        sha256sum $file | tee $file.sha256
      done
      FIN
    ]
  }

  # Its lame that the file provisioner onlly provisions local->remote, so just
  # use rsync to get the qcow2 image we build.
  provisioner "local-exec" {
    command = "rsync -av --progress -e 'ssh -F ${local.ssh_config}' --exclude '*.raw' --exclude kiwi.result --exclude build root@${libvirt_domain.node[count.index].name}:/srv/kiwi/out ."
  }
}
