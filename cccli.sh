#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/cccli"
INSTALL_BIN="/usr/local/bin/cccli"
SERVICE_NAME="cccli"
SUBSCRIPTION="${INSTALL_DIR}/subscription.yaml"
MIHOMO="${INSTALL_DIR}/mihomo"
MIHOMO_CONFIG="${INSTALL_DIR}/mihomo.yaml"
CONFIG_CONTENT=$'tun:\n  enable: true\n  stack: gvisor\n  auto-route: true\n  auto-redirect: true\n  auto-detect-interface: true\n  dns-hijack:\n    - any:53\n    - tcp://any:53\n  strict-route: true\n  exclude-uid:\n    - 0\n'
GHPROXY="https://gh-proxy.org/https://github.com"
MIHOMO_ASSET="v1.19.18/mihomo-linux-amd64-compatible-v1.19.18.gz"
SERVICE_CONTENT=$'[Unit]\nDescription=Mihomo (Clash Meta)\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\nType=simple\nExecStart=/opt/cccli/mihomo -d /opt/cccli -f /opt/cccli/mihomo.yaml\nRestart=on-failure\nRestartSec=3\nLimitNOFILE=1048576\n\n[Install]\nWantedBy=multi-user.target\n'

download_subscription() {
  local url="$1"
  sudo wget -q --show-progress --header="User-Agent: Clash.Meta" -O "${SUBSCRIPTION}" "$url"
}

validate_subscription_yaml() {
  if ! sudo test -s "${SUBSCRIPTION}"; then
    echo "error: empty subscription content" >&2
    exit 1
  fi

  if sudo grep -qiE '<!doctype|<html' "${SUBSCRIPTION}"; then
    echo "error: subscription does not look like yaml (html detected)" >&2
    exit 1
  fi

  if ! sudo grep -q ':' "${SUBSCRIPTION}"; then
    echo "error: subscription does not look like yaml" >&2
    exit 1
  fi
}

prompt_url() {
  local url
  read -r -p "Enter subscription URL: " url
  if [[ -z "${url}" ]]; then
    echo "error: subscription url is required" >&2
    exit 1
  fi
  printf '%s' "${url}"
}

cmd_update() {
  sudo mkdir -p "${INSTALL_DIR}"
  local url
  url="$(prompt_url)"
  download_subscription "${url}"
  validate_subscription_yaml

  printf '%s\n' "${CONFIG_CONTENT}" | sudo tee "${MIHOMO_CONFIG}" >/dev/null
  sudo sh -c "cat '${SUBSCRIPTION}' >> '${MIHOMO_CONFIG}'"
}

cmd_on() {
  sudo systemctl start "${SERVICE_NAME}"
}

cmd_off() {
  sudo systemctl stop "${SERVICE_NAME}"
}

cmd_status() {
  sudo systemctl status --no-pager "${SERVICE_NAME}"
}

cmd_setup() {
  local service_dst="/etc/systemd/system/cccli.service"
  local mihomo_url="${GHPROXY}/MetaCubeX/mihomo/releases/download/${MIHOMO_ASSET}"
  local geoip_url="${GHPROXY}/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat"
  local geosite_url="${GHPROXY}/MetaCubeX/meta-rules-dat/releases/latest/download/geosite.dat"
  sudo mkdir -p "${INSTALL_DIR}"

  echo "installing to ${INSTALL_DIR}"
  echo "installing script to ${INSTALL_BIN}"
  sudo cp -f "${SCRIPT_DIR}/$(basename "$0")" "${INSTALL_BIN}"
  sudo chmod +x "${INSTALL_BIN}"

  echo "downloading mihomo..."
  if [[ "${MIHOMO_ASSET}" == *.gz ]]; then
    local mihomo_gz="${MIHOMO}.gz"
    sudo wget -q --show-progress -O "${mihomo_gz}" "${mihomo_url}"
    sudo gunzip -f "${mihomo_gz}"
  else
    sudo wget -q --show-progress -O "${MIHOMO}" "${mihomo_url}"
  fi
  sudo chmod +x "${MIHOMO}"

  echo "downloading geoip/geosite..."
  sudo wget -q --show-progress -O "${INSTALL_DIR}/geoip.dat" "${geoip_url}"
  sudo wget -q --show-progress -O "${INSTALL_DIR}/geosite.dat" "${geosite_url}"

  echo "installed mihomo and geo data into ${INSTALL_DIR}"
  echo "installed script to ${INSTALL_BIN}"

  echo "writing systemd unit to ${service_dst}"
  printf '%s\n' "${SERVICE_CONTENT}" | sudo tee "${service_dst}" >/dev/null
  sudo systemctl daemon-reload
  echo "wrote ${service_dst}"
}

usage() {
  cat <<EOF
Usage: $0 <command>
Commands:
  on        start proxy
  off       stop proxy
  status    show proxy status
  update    download subscription and build mihomo.yaml
  setup     link systemd unit and download mihomo/geo data (amd64 only)
EOF
}

case "${1:-}" in
  on) cmd_on ;;
  off) cmd_off ;;
  status) cmd_status ;;
  update) cmd_update ;;
  setup) cmd_setup ;;
  *) usage; exit 1 ;;
esac
