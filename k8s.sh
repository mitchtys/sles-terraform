#!/usr/bin/env sh
#-*-mode: Shell-script; coding: utf-8;-*-
_base=$(basename "$0")
_dir=$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P || exit 126)
export _base _dir
set -xe

TMPDIR="${TMPDIR:-/tmp}"

# Wrapper script to handle installing k3s/rke/???

# For now, the assumption is you're installing *JUST* k3s or rke, dual clusters
# isn't a thing yet if ever. My thought on that is you bridge disparate clusters
# together network wise not build rke and k3s on the same vm's.
#
# Note that functions if omitted are essentially nops, that is intentional, if
# the function defining say rke_post is missing, then just don't define it and
# all that happens is we don't run a function and deal with the exec()/fork() of
# a shell process over ssh by terraform. No bigs. This also reduces a ton of
# useless if/then indentation and needless logic proliferation.

action=$1
shift
index=$1
shift
flavor=$1
shift
firstnode=${1:-""}

if [ "${flavor}" != "rke" ] && [ "${flavor}" != "k3s" ]; then
    exit 0
fi

common_pre() {
  if [ "${index}" = "0" ]; then
    hostname
    rm -fr /usr/local/sbin/{rke,helm,k9s}

    # Install helm
    {
      curl -Ls https://get.helm.sh/helm-$(curl -Ls "https://api.github.com/repos/helm/helm/releases/latest" | jq -r '.tag_name')-linux-amd64.tar.gz | tar -xz -C /usr/local/sbin --strip-components=1 linux-amd64/helm
    } &

    # And k9s
    {
      curl -Ls $(curl -Ls "https://api.github.com/repos/derailed/k9s/releases/latest" | jq -r '.assets[] | select(.browser_download_url | contains("Linux_x86_64")) | .browser_download_url') | tar -C /usr/local/sbin -xzf - k9s
    } &
  fi
}

rke_pre() {
  common_pre
  if [ "${index}" = "0" ]; then
    {
        curl -Ls -o /usr/local/sbin/rke $(curl -Ls "https://api.github.com/repos/rancher/rke/releases/latest" | jq -r '.assets[] | select(.browser_download_url | contains("linux-amd64")) | .browser_download_url') && chmod 755 /usr/local/sbin/rke
    } &
  fi

  # TODO: We don't want docker in k3s really, test if its running and turn it
  # off?
  #
  # Future me figure this out for weird setups or make them impossible based
  # on more understanding.
  systemctl enable docker
  systemctl start docker
  wait
}

rke_install() {
  if [ "${index}" = "0" ]; then
    cd /root
    rke up
  fi
}

rke=/root/kube_config_cluster.yml
k3s=/etc/rancher/k3s/k3s.yaml

# Nuke the KUBECONFIG sh files and if kubectl isn't present snag that too iff we
# have a config file setup
common_post() {
  rm -fr /etc/profile.d/{rke,k3s}.sh
  if ! command -v kubectl && [ "${index}" = "0" ]; then
    curl -o /usr/local/sbin/kubectl -L "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod 755 /usr/local/sbin/kubectl
  fi
}

rke_post() {
  common_post
  if [ -e "${rke}" ]; then
    echo "export KUBECONFIG=${rke}" | tee /etc/profile.d/rke.sh
  fi
}

# Abuse pre a bit to install k3s on the master node only
k3s_pre() {
  common_pre
  if [ "${index}" = "0" ]; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.19.5+k3s2 sh -s -
  fi
  wait
}

# And then install to install on the rest
k3s_install() {
  if [ "${index}" != "0" ]; then
    if ! command -v k3s; then
      token=$(ssh ${firstnode} "cat /var/lib/rancher/k3s/server/node-token")
      curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.19.5+k3s2 K3S_URL=https://${firstnode}:6443 K3S_TOKEN=$token sh -
    fi
  fi
}

k3s_post() {
  common_post
  if [ -e "${k3s}" ]; then
    echo "export KUBECONFIG=${k3s}" | tee /etc/profile.d/k3s.sh
  fi
}

wat="${flavor}_${action}"

# If there isn't an flavor/action function defined, don't do anything.
if command -v "${wat}" 2>&1; then
  ${wat}
fi
