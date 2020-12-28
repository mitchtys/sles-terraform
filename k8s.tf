variable with_k8s {
  description = "whether or not to install a k8s distribution or not options are k3s or rke"
  type        = string
  default     = "none"
}

resource "local_file" "rke_cluster" {
  count = var.with_k8s == "rke" ? 1 : 0
  depends_on      = [
    libvirt_domain.node
  ]
  file_permission = "0644"
  filename        = "${abspath(path.root)}/rke-cluster-${terraform.workspace}"
  content = templatefile("${path.root}/rke-cluster.template", {
        hosts = local.host_id,
        count = local.count
    })
}

resource "null_resource" "k8s_files" {
  count      = local.count
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    source      = "k8s.sh"
    destination = "/tmp/k8s.sh"
  }
}

resource "null_resource" "k8s_rke_clusteryaml" {
  count = var.with_k8s == "rke" ? 1 : 0
  depends_on = [
    local_file.rke_cluster,
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    source = "${abspath(path.root)}/rke-cluster-${terraform.workspace}"
    destination = "/root/cluster.yml"
  }
}

resource "null_resource" "k8s_pre" {
  count      = local.count
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.k8s_files,
    null_resource.k8s_rke_clusteryaml
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      sh /tmp/k8s.sh pre ${count.index} ${var.with_k8s}
    FIN
    ]
  }
}

resource "null_resource" "k8s_install" {
  count      = local.count
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.k8s_files,
    null_resource.k8s_pre
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      sh /tmp/k8s.sh install ${count.index} ${var.with_k8s} ${libvirt_domain.node[0].network_interface[0].hostname}
    FIN
    ]
  }
}

resource "null_resource" "k8s_post" {
  count      = local.count
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.k8s_files,
    null_resource.k8s_install
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
      sh /tmp/k8s.sh post ${count.index} ${var.with_k8s}
    FIN
    ]
  }
}
