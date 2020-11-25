#!/bin/sh

# Let .kconfig/.profiles be used if present
#shellcheck disable=SC1091
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# Also debug profiles (will use again later)
#shellcheck disable=SC2154
echo "debug: kiwi_iname=$kiwi_iname kiwi_profiles=$kiwi_profiles"

rm -fr /etc/machine-id /var/lib/zypp/AnonymousUniqueId /var/lib/systemd/random-seed

suseSetupProduct

suseInsertService sshd
suseInsertService network
suseInsertService cloud-init-local
suseInsertService cloud-init
suseInsertService cloud-config
suseInsertService cloud-final

baseSetRunlevel 3

suseImportBuildKey

cat >/etc/sysconfig/network/ifcfg-eth0 <<EOF
BOOTPROTO='dhcp'
MTU=''
REMOTE_IPADDR=''
STARTMODE='auto'
ETHTOOL_OPTIONS=''
USERCONTROL='no'
EOF

chkconfig sshd on

baseStripRPM

baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_SET_HOSTNAME yes

sed -i 's/.*rpm.install.excludedocs.*/rpm.install.excludedocs = yes/g' /etc/zypp/zypp.conf

# TODO: Do I really need this? Everything is through the serial console or ssh...
echo FONT="$CONSOLE_FONT" >> /etc/vconsole.conf

update-ca-certificates

[ ! -s /var/log/zypper.log ] && install -m 644 /dev/null /var/log/zypper.log

for i in /usr/lib/rpm/gnupg/keys/gpg-pubkey*asc; do
  rpm --import "$i" || :
done

suseConfig

/sbin/ldconfig

baseCleanMount

exit 0
