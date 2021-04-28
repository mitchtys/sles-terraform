variable "with_rke2" {
  type        = bool
  description = "if rke2 should be installed or not"
  default     = "false"
}

variable "rke2_version" {
  type        = string
  description = "version of rke2 to install"
  default     = "changeme"
}

variable "rke2_servers" {
  type        = number
  description = "how many rke2 nodes should be considered control-nodes or servers, all the rest are agents"
  default     = "1"
}

variable "rke2_schedule" {
  type        = bool
  description = "control if the control-nodes should be scheduleable by default or not, by default they are schedulable"
  default     = "true"
}

variable "rke2_token" {
  type        = string
  description = "token to use for rke2 config.yaml"
  default     = "changeme"
}

# Handles first master rke2 install, this config.yaml is unique compared to the rest
resource "null_resource" "rke2_prime" {
  count = var.with_rke2 ? 1 : 0
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.ssh_setup_user
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    content     = templatefile("${path.root}/rke2-config-yaml.template", {
        server   = "",
        schedule = var.rke2_schedule,
        token    = var.rke2_token
        tls_san  = [
          libvirt_domain.node[count.index].network_interface[0].addresses[0],
          local.id_host[0]
        ]
        }
      )
    destination = "/root/config.yaml"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
set -xe
install -dm755 /etc/rancher/rke2
install -m640 /root/config.yaml /etc/rancher/rke2

curl -sfL https://get.rke2.io -o /root/rke2-install.sh
chmod 755 /root/rke2-install.sh

if [ ${var.rke2_version} = "changeme" ]; then
  /root/rke2-install.sh
else
  env INSTALL_RKE2_VERSION=${var.rke2_version} /root/rke2-install.sh
fi

systemctl enable rke2-server
systemctl start rke2-server

echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" | tee /etc/profile.d/rke2.sh
echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" | tee -a /etc/profile.d/rke2.sh

source /etc/profile.d/rke2.sh

while true; do
 if [ $(kubectl get nodes | awk "/$(hostname)/ {print \$2}") = "Ready" ]; then
    break
  else
    sleep $(awk 'BEGIN { srand(systime()); print int(5*rand()+1)}')
  fi
done
    FIN
    ]
  }
}

# # All following/subsequent servers get added via this resource
resource "null_resource" "rke2_servers" {
  count = (var.with_rke2 && ((local.count - (var.rke2_servers - 1)) > 0)) ? (var.rke2_servers - 1) : 0
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.ssh_setup_user,
    null_resource.rke2_prime
  ]


  connection {
    host        = libvirt_domain.node[(count.index+1)].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    content     = templatefile("${path.root}/rke2-config-yaml.template", {
        server   = libvirt_domain.node[0].network_interface[0].addresses[0],
        schedule = var.rke2_schedule,
        token    = var.rke2_token,
        tls_san  = []
        }
      )
    destination = "/root/config.yaml"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
set -xe
install -dm755 /etc/rancher/rke2
install -m640 /root/config.yaml /etc/rancher/rke2

curl -sfL https://get.rke2.io -o /root/rke2-install.sh
chmod 755 /root/rke2-install.sh

if [ ${var.rke2_version} = "changeme" ]; then
  /root/rke2-install.sh
else
  env INSTALL_RKE2_VERSION=${var.rke2_version} /root/rke2-install.sh
fi

systemctl enable rke2-server
systemctl start rke2-server

echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" | tee /etc/profile.d/rke2.sh
echo "export PATH=\$PATH:/var/lib/rancher/rke2/bin" | tee -a /etc/profile.d/rke2.sh

source /etc/profile.d/rke2.sh

while true; do
  if [ $(kubectl get nodes | awk "/$(hostname)/ {print \$2}") = "Ready" ]; then
    break
  else
    sleep $(awk 'BEGIN { srand(systime()); print int(5*rand()+1)}')
  fi
done
    FIN
    ]
  }
}

# All following/subsequent servers get added via this resource
resource "null_resource" "rke2_agents" {
  count = (var.with_rke2 && ((local.count - var.rke2_servers) > 0)) ? (local.count - var.rke2_servers) : 0
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.ssh_setup_user,
    null_resource.rke2_prime
  ]

  connection {
    host        = libvirt_domain.node[(count.index+var.rke2_servers)].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    content     = templatefile("${path.root}/rke2-config-yaml.template", {
        server   = libvirt_domain.node[0].network_interface[0].addresses[0],
        schedule = var.rke2_schedule,
        token    = var.rke2_token,
        tls_san  = []
        }
      )
    destination = "/root/config.yaml"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
set -xe
install -dm755 /etc/rancher/rke2
install -m640 /root/config.yaml /etc/rancher/rke2

curl -sfL https://get.rke2.io -o /root/rke2-install.sh
chmod 755 /root/rke2-install.sh

if [ ${var.rke2_version} = "changeme" ]; then
  /root/rke2-install.sh
else
  env INSTALL_RKE2_VERSION=${var.rke2_version} /root/rke2-install.sh
fi

systemctl enable rke2-agent
systemctl start rke2-agent
FIN
    ]
  }
}

# HERE BE HACKS
variable "short_dns_ttl" {
  type        = bool
  default     = true
  description = "Whether to set short dns ttl's or not."
}

locals {
  dns_ttl = var.short_dns_ttl ? 120 : 43200
}

variable "hack_cloudflare_dns_zoneid" {
  type        = string
  description = "zoneid for rancher"
  default     = "changeme"
}

variable "cloudflare_api_token" {
  type        = string
  description = "cloudflare api token used to login to cloudflare account"
  default     = "changeme"
}

provider "cloudflare" {
  version   = "~> 2.0"
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "rancher_hack" {
  zone_id    = var.hack_cloudflare_dns_zoneid
  name       = "rancher"
  value      = libvirt_domain.node[0].network_interface[0].addresses[0]
  type       = "A"
  ttl        = local.dns_ttl
}

variable "rancher_subdomain" {
  type        = string
  description = "the subdomain to use for the rancher hostname"
  default     = "rancher"
}

variable "rancher_domain" {
  type        = string
  description = "the domain to use for the rancher hostname"
  default     = "example.com"
}

locals {
  rancher_hostname = "${var.rancher_subdomain}.${var.rancher_domain}"
}

resource "null_resource" "k8s_hack" {
  count = var.with_rke2 ? 1 : 0
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.ssh_setup_user
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
set -xe
curl -Ls https://get.helm.sh/helm-$(curl -Ls "https://api.github.com/repos/helm/helm/releases/latest" | jq -r '.tag_name')-linux-amd64.tar.gz | tar -xz -C /usr/local/sbin --strip-components=1 linux-amd64/helm &
curl -Ls $(curl -Ls "https://api.github.com/repos/derailed/k9s/releases/latest" | jq -r '.assets[] | select(.browser_download_url | contains("Linux_x86_64")) | .browser_download_url') | sudo tar -C /usr/local/sbin -xzf - k9s &
wait
FIN
    ]
  }
}

# hack to "do stuff" after the install
resource "null_resource" "rke2_hack" {
  count = var.with_rke2 ? 1 : 0
  depends_on = [
    libvirt_domain.node,
    tls_private_key.ssh_key,
    local_file.ssh_private_key,
    local_file.ssh_public_key,
    null_resource.ssh_setup_root,
    null_resource.ssh_setup_user,
    null_resource.rke2_prime,
    null_resource.rke2_servers,
    null_resource.k8s_hack,
    cloudflare_record.rancher_hack
  ]

  connection {
    host        = libvirt_domain.node[count.index].network_interface[0].addresses[0]
    private_key = tls_private_key.ssh_key.private_key_pem
    type        = "ssh"
    user        = "root"
  }

  provisioner "remote-exec" {
    inline = [<<-FIN
helm repo add jetstack https://charts.jetstack.io

helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

for x in cert-manager cert-manager-cainjector cert-manager-webhook; do
  kubectl -n cert-manager rollout status "deploy/$x"
done

# extra fudge in case of pods not responding immediately
sleep $(awk 'BEGIN { srand(systime()); print int(5*rand()+1)}')

helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm upgrade --install rancher rancher-stable/rancher --namespace cattle-system --create-namespace --set hostname=${local.rancher_hostname}
kubectl -n cattle-system rollout status deploy/rancher

helm repo add rancher-charts https://charts.rancher.io

helm upgrade --install rancher-gatekeeper-crd rancher-charts/rancher-gatekeeper-crd --namespace=cattle-gatekeeper-system --create-namespace --wait
helm upgrade --install rancher-gatekeeper rancher-charts/rancher-gatekeeper --namespace=cattle-gatekeeper-system --create-namespace --wait

helm upgrade --install rancher-monitoring-crd rancher-charts/rancher-monitoring-crd --namespace=cattle-monitoring-system --create-namespace --wait
helm upgrade --install rancher-monitoring rancher-charts/rancher-monitoring --namespace=cattle-monitoring-system --create-namespace --wait --set prometheus.prometheusSpec.resources.limits.memory=2500Mi

# Nope, what label do we need to tell the admithook to not deny nodes that are coming online
# for x in $(kubectl get namespace | awk '/cattle|rancher|kube/ {print $1}'); do
#   kubectl label namespace $x --overwrite admission.gatekeeper.sh/ignore="test"
# done
    FIN
    ]
  }
}
