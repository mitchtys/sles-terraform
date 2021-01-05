#!/usr/bin/env sh
#-*-mode: Shell-script; coding: utf-8;-*-
_base=$(basename "$0")
_dir=$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P || exit 126)
export _base _dir

# TODO: real command/arg parsing? Not sure its worth it tbh.
action=$1
shift
cache=$1

install -dm755 "${cache}"
TMPDIR="${TMPDIR:-/ssd/tmp}"
TMPDIR=/ssd/tmp
tmp=$(mktemp -d -t image-XXXXXXX)
_tmp="${tmp}"

cleanup() {
  rm -fr ${tmp}
}

trap cleanup EXIT

if [ ! -d "${tmp}" ]; then
  exit 125
fi

(cd "${cache}" && find . -print -name "*.iso" -type f -exec cp {} "${_tmp}" \;)

find "${_tmp}"

repos="http://download.suse.de/ibs/Devel:/PubCloud/SLE_15_SP2/Devel:PubCloud.repo"
rpms="cloud-init docker which jq perf"

# Note, this is only intended to run from the directory its in in git. Reason
# being it expects the bento templates to be where they are in the checkout for
# simplicity.

# Logic/role/responsibility:
# Take user variable inputs, map that to a hash (sha256)
# Iff there is no file(s) by that hash name in the cache dir, then update/build
# an image and put the image into the cache dir.
# The return of this script is the hash of the variable inputs, which is used in
# terraform to find the path to the image to boot.

# The intent is to make it possible to use bento default packer configs, and
# then edit them to new names and *then* use that in packer to build images.

# This way we can easily update things on an as needed basis and check in the
# updates yet allow for others to more easily add things to default definitions.
#
# Its not perfect, but its better than using say patches for this and editing
# things manually.

# Logik for now:
# - foreach zypper repo add a new listentry for autoyast to install to /profile/add-on/add_on_products
# - foreach rpm add a new package entry to /profile/software/packages

# xmlstarlet/xml editing is not.. intuitive at all
# because there are xml namespaces we have to select them via _ (or name them but eff that noise)
# Then we can add to the node we want (listentry) then under there add what we need to on top of that new node
# finally, we have to use xml unesc to make sure the CDATA we added is added with <'s and not &lt; text

src=bento/packer_templates/sles/http/sles-15-sp2-x86_64-autoinst.xml
dst=bento/packer_templates/sles/http/sles-15-sp2-x86_64-autoinst.xml.test
tmp="${tmp} ${dst}"

cfg=$(basename bento/packer_templates/sles/http/sles-15-sp2-x86_64-autoinst.xml.test)

# xml ed --subnode "//_:profile/_:add-on/_:add_on_products" -t elem -n listentry -v '' \
#        --subnode "//_:profile/_:add-on/_:add_on_products/listentry" -t elem -n product_dir -v '/' \
#        --subnode "//_:profile/_:add-on/_:add_on_products/listentry" -t elem -n product \
#        --subnode "//_:profile/_:add-on/_:add_on_products/listentry" -t elem -n media_url -v "<![CDATA[${repos}]]>" \
#        "$src" | xml unesc > "${dst}"

# xml ed --update "//_:bootloader/_:global/_:append" -v "blah" \
#     "$src" > "${dst}"

append="plymouth.enable=0 console=ttyS0,115200n8 console=tty0 net.ifnames=0 rd.shell rd.debug log_buf_len=1M rd.kiwi.debug"
xml ed --update "//_:bootloader/_:global/_:append" -x "concat(., ' ${append}')" \
    "$src" > "${dst}"


git diff --no-index "${src}" "${dst}"

# PACKER_CACHE_DIR="${_tmp}" packer build -var build_directory="${_tmp}/build" -var "mirror=${_tmp}" -var "autoinst_cfg=${cfg}" --only=qemu bento/packer_templates/sles/sles-15-sp2.json

exit 0
shift
source_xml=$1
shift
source_json=$1
shift
cmdline_default=$1
shift
cmdline_user=$1
shift
repos=$1
shift
rpms=$1
