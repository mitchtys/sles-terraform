variable with_zypper {
  description = "whether or not to install a k8s distribution or not options are k3s or rke"
  type        = bool
  default     = false
}

resource "null_resource" "zypper_repos" {
  count      = var.with_zypper ? 1 : 0
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

  provisioner "remote-exec" {
    inline = [<<-FIN
      set -e
for repofile in $(ls -1 /etc/zypp/repos.d/); do zypper rr $(basename $repofile .repo); done
rm -fr /etc/zypp/repos.d/*
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-SP2/x86_64/product/ sles15sp2-product
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-SP2/x86_64/update/SUSE:Updates:SLE-Product-SLES:15-SP2:x86_64.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product/ sles15sp2-module-basesystem
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update/SUSE:Updates:SLE-Module-Basesystem:15-SP2:x86_64.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Products/SLE-Module-Desktop-Applications/15-SP2/x86_64/product/ sles15sp2-module-desktop-apps
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP2/x86_64/update/SUSE:Updates:SLE-Module-Desktop-Applications:15-SP2:x86_64.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Products/SLE-Module-Development-Tools/15-SP2/x86_64/product/ sles15sp2-module-dev-tools
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Development-Tools/15-SP2/x86_64/update/SUSE:Updates:SLE-Module-Development-Tools:15-SP2:x86_64.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Products/SLE-Manager-Tools/15/x86_64/product/ sles15-manager-tools
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE/Updates/SLE-Manager-Tools/15/x86_64/update/SUSE:Updates:SLE-Manager-Tools:15:x86_64.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/Devel:/Galaxy:/Manager:/3.2:/SLE15-SUSE-Manager-Tools/SLE_15/Devel:Galaxy:Manager:3.2:SLE15-SUSE-Manager-Tools.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/GA/standard/SUSE:SLE-15-SP2:GA.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update/standard/SUSE:SLE-15-SP2:Update.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/  http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/SUSE:SLE-15:GA.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15:/Update/standard/SUSE:SLE-15:Update.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/CaaSP:/4.5:/Update/standard/SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5:Update.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/CaaSP:/4.5:/Update:/CR/containers/SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5:Update:CR.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP2/SUSE:CA.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update/standard/SUSE:SLE-15-SP1:Update.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/GA/standard/SUSE:SLE-15-SP1:GA.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/Devel:/PubCloud/SLE_15_SP2/Devel:PubCloud.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/Devel:/CaaSP:/4.5/SLE_15_SP2/Devel:CaaSP:4.5.repo
zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/SES7/standard/SUSE:SLE-15-SP2:Update:Products:SES7.repo

zypper ar --no-check --no-gpgcheck --no-refresh http://download.suse.de/ibs/Devel:/Docker/SUSE_SLE-15_GA_standard/Devel:Docker.repo

# http://download.suse.de/ibs/Devel:/PubCloud/SLE_15_SP2/Devel:PubCloud.repo
# http://download.suse.de/ibs/Devel:/CaaSP:/4.5/SLE_15_SP2/Devel:CaaSP:4.5.repo
# http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/SES7/standard/SUSE:SLE-15-SP2:Update:Products:SES7.repo

zypper refresh
# <path project="SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5:Update" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:Update" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:GA" repository="standard"/>
# <repository name="images">
# <path project="openSUSE.org:Virtualization:Appliances:Builder" repository="SLE_15_SP2"/>
# <path project="SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5:Update" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:Update:Products:CaaSP:4.5" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:Update" repository="standard"/>
# <path project="SUSE:SLE-15-SP2:GA" repository="standard"/>
# <path project="SUSE:CA" repository="SLE_15_SP2"/>
# <path project="SUSE:SLE-15-SP2:Update:Products:SES7:Update" repository="standard"/>
# <arch>x86_64</arch>
# </repository>
wait
    FIN
    ]
  }
}
