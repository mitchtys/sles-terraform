# Keeping these vars by their sources for now. Will break this apart later.
# variable packer_isos {
#   description = "map of filename keys, with values being their source uri's"
#   type = map(string, string)
#   default = {
#     "SLE-15-SP2-Full-x86_64-GM-Media1.iso" => "http://download.suse.de/install/SLE-15-SP2-Full-GM/SLE-15-SP2-Full-x86_64-GM-Media1.iso ",
#     "SLE-15-SP2-Full-x86_64-QU1-Media1.iso" => "http://download.suse.de/install/SLE-15-SP2-Full-QU1/SLE-15-SP2-Full-x86_64-QU1-Media1.iso"
#   }
# }

locals {
  downloader = "${path.root}/dlshasum.sh"
  #tmpdir = "${path.root}/tmp"
  tmpdir = "${path.root}/packer_cache"
  cachedir = "${path.root}/.cache"
}

# Responsible for downloading/updating the iso's used by packer/autoyast into the .cache dir
resource "shell_script" "isos" {
  for_each = {
    "SLE-15-SP2-Full-x86_64-GM-Media1.iso" = "http://download.suse.de/install/SLE-15-SP2-Full-GM/SLE-15-SP2-Full-x86_64-GM-Media1.iso ",
    "SLE-15-SP2-Full-x86_64-QU1-Media1.iso" = "http://download.suse.de/install/SLE-15-SP2-Full-QU1/SLE-15-SP2-Full-x86_64-QU1-Media1.iso"
  }
  lifecycle_commands {
    # TODO: These iso's are 10gig each, removing them is silly and would add
    # hours on each rebuild and just download the same data constantly.
    #
    # Perhaps another idea, save things to a temp cache dir as their sha256sum
    # and hard link to the name/from there? Brain on this a bit.
    # delete = "${local.downloader} delete ${local.cachedir}/${each.key} ${each.value}"
    create = "${local.downloader} create ${local.cachedir}/${each.key} ${each.value}"
    update = "${local.downloader} update ${local.cachedir}/${each.key} ${each.value}"
    read   = "${local.downloader} read ${local.cachedir}/${each.key} ${each.value}"
  }
}

# TODO: Need to figure out a way to specify this per major/sp rev
#
# Probably a simple map of like sles15 -> {"a": 'b'}, sle15sp2 -> {"b": "c"}
# kinda deal will work. Future me brain it out.
variable zypper_repos {
  description = "just a space delimited list of http repos to add/be used for image building"
  type = string
  default = "http://download.suse.de/ibs/Devel:/PubCloud/SLE_15_SP2/Devel:PubCloud.repo"
}

variable required_zypper_rpms {
  description = "rpms that need to be installed or some images won't boot, caveat emptor if you change this"
  type = string
  default = "cloud-init"
}


# You can argue on some of these being needed, but stuff like
# tcpdump/perf/etc... makes debugging soooo much easier.
variable zypper_rpms {
  description = "just a space delimited list of additional rpms for autoyast to install"
  type = string
  default = "docker jq tcpdump perf rsync vim curl"
}

# CAVEAT EMPTOR! This is necessary for the terraform libvirt integration, make
# sure you know what you're doing if you change this! If the image you build
# doesn't have virtual consoles working, terraform-libvirt will fail to boot
# them. These params are "tried and true" or "known to work". Hence 'required'.
#
# TODO: bisect down what is really needed or not, some of these are more "nice
# to have" like the rd. vars for dracut debugging.
variable required_append_cmdline {
  description = "what to append to the kernel command line"
  type = string
  default = "plymouth.enable=0 console=ttyS0,115200n8 console=tty0 net.ifnames=0 rd.shell rd.debug log_buf_len=1M rd.kiwi.debug"
}

# This is probably the variable you want to set if you're setting/adding kernel
# command line args, not the above variable. That one is appended after this
# however so anything here can get blitzed by the required setup.
variable user_cmdline {
  description = "what to add to the built images kernel command line"
  type = string
  default = ""
}

# The meat of image builds for now. At some point I might get kiwi integrated in
# as well but not any time soon as it means spinning up another vm, running kiwi
# getting the image and then spinning the vm down. (this sounds simple but
# involves more dragons than might be present at a comic con convention)
#
# Kiwi doesn't really fit into this model very well in that it needs a vm or say
# qemu to build stuff. Won't work well on a macos system.
#
# But the strategy here is this, we take the variables above with zypper
# uris/packages/kernel args and copy the autoyast xml files and edit them via
# this script to have what we need to boot.
#
# The variables themselves are hashed so as not to rebuild boot images
# needlessly. The hash of the image is what is used for booting. Aka, if you
# never change any of the variables here, you'll only build the qcow2/etc...
# images once even if you switch workspaces. But if in one workspace you had a
# .tfvars file that modified things, you would pay the build image penalty once
# each time you changed vars. But as long as you didn't change the varibles
# again, should end up with that penalty only once.
#
# If anything this script "does too much" but not sure of a cleaner way for now.
resource "shell_script" "boot_image" {
  lifecycle_commands {
    # TODO: These iso's are 10gig each, removing them is silly and would add
    # hours on each rebuild and just download the same data constantly.
    #
    # Perhaps another idea, save things to a temp cache dir as their sha256sum
    # and hard link to the name/from there? Brain on this a bit.
    # delete = "${local.downloader} delete ${local.cachedir}/${each.key} ${each.value}"
    create = "${local.downloader} create ${local.cachedir}/${each.key} ${each.value}"
    update = "${local.downloader} update ${local.cachedir}/${each.key} ${each.value}"
    read   = "${local.downloader} read ${local.cachedir}/${each.key} ${each.value}"
  }
}
