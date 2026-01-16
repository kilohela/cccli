# Clash Controller CLI (cccli)

Clash Controller CLI (cccli) is a small Bash utility that installs and manages a local Mihomo (Clash Meta) proxy service via systemd. It downloads Mihomo and geo data, writes a systemd unit, and provides simple commands to start/stop the service and update the subscription-based configuration.

## Features

- One-command setup for Mihomo + geo data
- Creates a systemd service for background running
- Updates `mihomo.yaml` using a subscription URL
- Simple `on/off/status/update` commands

## Requirements

- Linux with systemd
- `sudo` privileges
- `wget`, `gunzip`
- amd64/x86_64 only (the bundled asset is `mihomo-linux-amd64-compatible`)
- Permission to create and use a TUN device (typically allowed on a normal Linux host)
- Permission to adjust routing/DNS for TUN (usually blocked in containers)

## Installation

Run setup to install the script, Mihomo, geo data, and systemd unit:

```bash
./cccli.sh setup
```

This installs:

- Script: `/usr/local/bin/cccli`
- Mihomo + data: `/opt/cccli/`
- Service: `/etc/systemd/system/cccli.service`

## Usage

First-time use: run `update` before turning the service on so `mihomo.yaml` exists.

```bash
cccli on      # start proxy
cccli off     # stop proxy
cccli status  # check service status
cccli update  # download subscription and build mihomo.yaml
```

### Update subscription

`cccli update` prompts for a subscription URL and writes `/opt/cccli/mihomo.yaml` by combining a built-in base config with the downloaded subscription.

### Default behavior

The built-in base config enables TUN mode by default (gVisor stack, auto-route, auto-redirect, and DNS hijack).

## Notes

- The script uses `https://gh-proxy.org/` for downloads.
- If your environment requires different assets or architecture, adjust `MIHOMO_ASSET` in `cccli.sh`.

## Uninstall

```bash
sudo systemctl stop cccli
sudo rm -f /etc/systemd/system/cccli.service
sudo systemctl daemon-reload
sudo rm -rf /opt/cccli
sudo rm -f /usr/local/bin/cccli
```
