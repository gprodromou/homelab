# 🏠 Homelab — Self-Hosted Media Server

A headless Debian home server running a fully containerized media pipeline: VPN-isolated torrent downloading, Plex media streaming, automatic subtitles, network-wide services, and secure remote access — all managed from a browser, with zero client-side software.

Built and documented from scratch as a hands-on infrastructure project.

**Author:** Giorgos Prodromou

---

## Overview

This project turns an old desktop (Intel i5-3470, 16 GB RAM) into a self-sufficient media server. Everything runs in Docker containers orchestrated via Portainer, with each service isolated and independently configurable.

The core design principle: **the server does the work 24/7, the client is just a remote control.** Downloads continue whether or not any personal device is on, and the entire stack is reachable securely from anywhere via a mesh VPN — without exposing anything to the public internet.

![Dashboard](docs/screenshots/dashboard.png)

*The Homepage dashboard, accessed securely over HTTPS via Tailscale MagicDNS.*

---

## Architecture

**Debian Host (headless):**

- **Internet** enters through **gluetun** (PIA VPN with port forwarding)
- **Deluge** runs inside gluetun's network — no traffic can leave without the VPN
- **Media & files:** Plex, Bazarr, FileBrowser Quantum
- **Network services:** AdGuard Home, Nginx Proxy Manager
- **Management:** Homepage dashboard, Portainer
- **Remote access:** Tailscale (mesh VPN + subnet router)

**Storage:**

| Disk | Mount | Purpose |
|------|-------|---------|
| 250 GB | `/` | OS + container configs |
| 500 GB | `/mnt/data_500gb` | Active downloads (temporary) |
| 1 TB | `/mnt/data_1tb` | Media library + config backups |

**Access:** Mac, iPhone, and Smart TVs connect from any network through the encrypted Tailscale mesh — nothing is exposed to the public internet.

---

## Services

| Service | Role | Notes |
|---------|------|-------|
| **Deluge** | Torrent client | Runs inside gluetun's network — physically cannot leak real IP |
| **gluetun** | VPN gateway | Private Internet Access, with **port forwarding** for better peer connectivity |
| **Plex** | Media server | Streams to Smart TVs, phones, browsers; remote sharing with 2FA-protected account |
| **Bazarr** | Subtitles | Automatically fetches English subtitles (Gestdown, subf2m, TVSubtitles) |
| **FileBrowser Quantum** | File manager | Web UI to preview/download non-media files (books, PDFs) to any device |
| **AdGuard Home** | DNS ad-blocker | Network-level ad filtering |
| **Nginx Proxy Manager** | Reverse proxy | Clean local domains for each service |
| **Homepage** | Dashboard | Single pane of glass with live widgets (system, VPN, Plex, Deluge) |
| **Portainer** | Container management | Docker stack orchestration via UI |
| **Tailscale** | Mesh VPN | Secure remote access from anywhere, no exposed ports |

---

## Key Features

### VPN isolation (kill-switch by design)

Deluge uses `network_mode: service:gluetun` — it has **no network stack of its own**. If the VPN drops, Deluge has no route to the internet whatsoever. This isn't a kill-switch that "activates"; it's a structural impossibility to leak.

![VPN isolation proof](docs/screenshots/VPN_isolation_proof.png)

*The host's real IP (Cyprus) vs. the torrent client's IP (Netherlands, via PIA). Traffic is provably isolated.*

PIA **port forwarding** is auto-synced to Deluge every 10 minutes via a cron script, improving download speeds without manual intervention.

### Storage architecture

Three physical disks with clear separation of concerns. Media disks are mounted by **UUID** (not `/dev/sdX`) in `/etc/fstab` with the `nofail` flag — so a disk failure never blocks boot on a headless machine.

![Storage architecture](docs/screenshots/storage_architecture.png)

Data is treated as disposable (watch-and-delete), so no RAID — the focus is on protecting **configuration**, which is backed up.

### Secure remote access (Tailscale)

The entire homelab is reachable from anywhere — the office, mobile data, traveling — through a **Tailscale mesh VPN** (WireGuard-based). Only the user's own authenticated devices can connect; **nothing is exposed to the public internet**. Subnet routing makes the whole LAN reachable, and Tailscale Serve provides automatic HTTPS with a clean hostname.

### Automated media pipeline

1. Add torrent in Deluge with a label (`movies`, `tv`, or `misc`)
2. Downloads via VPN to the 500 GB disk
3. On completion, the file is moved to the correct folder on the 1 TB disk
4. **Movies / TV** → Plex auto-scans and adds to the library
5. **Misc** (books, PDFs) → available in FileBrowser to download to any device

### Monitoring & backups

A nightly cron job (4 AM) archives all configs and Portainer data, keeps the last 7, and reports success/failure to a **Discord channel** — so a silent backup failure is impossible to miss.

![Discord backup alerts](docs/screenshots/discord_backup_alert.png)

*Automated daily backup notifications, running unattended for days.*

---

## Security Hardening

| Measure | Protection |
|---------|-----------|
| SSH key-only auth | Password login **disabled**; brute-force impossible |
| Root login disabled | No direct attacks on root |
| Fail2ban | Auto-bans repeated SSH failures |
| UFW firewall | Only required ports open |
| Unattended-upgrades | Debian security patches applied automatically |
| VPN isolation | Torrent traffic never exposes real IP |
| Plex 2FA | The only internet-facing account is protected |
| Tailscale-only access | No exposed ports for management services |
| Off-site config backup | This repository (secrets excluded) |

---

## Repository Structure

Each service lives in its own Docker Compose stack under `stacks/`:

- `stacks/downloads/` — gluetun + Deluge (VPN-isolated)
- `stacks/plex/`
- `stacks/bazarr/`
- `stacks/filebrowser/`
- `stacks/adguard/`
- `stacks/npm/`
- `stacks/homepage/`
- `stacks/tailscale/`
- `scripts/` — backup + automation scripts
- `docs/screenshots/`

Every stack includes a `docker-compose.yml`. Secrets live in `.env` files (gitignored); each has a `.env.example` template showing the required variables.

---

## Setup Notes

This repo documents a personal setup; it's not a one-click deploy. To adapt it:

1. Copy each `.env.example` to `.env` and fill in your own values (VPN credentials, tokens, etc.)
2. Adjust volume paths in the compose files to match your storage
3. Deploy each stack via Portainer or `docker compose up -d`

Secrets (VPN passwords, API tokens, webhook URLs, auth keys) are **never** committed — they stay local and are excluded via `.gitignore`.

---

## Lessons & Design Decisions

- **`network_mode: service:gluetun`** over a kill-switch — isolation by architecture beats isolation by rule.
- **UUID mounts + `nofail`** — the correct way to mount disks on a headless box.
- **Tailscale over port forwarding** — remote access without an attack surface.
- **Hardware transcoding on Ivy Bridge** required the legacy `i965` VAAPI driver, not the modern `iHD` — a non-obvious fix for pre-Broadwell Intel iGPUs.
- **Config-as-backup** — data is disposable, but configuration is the real asset; hence daily backups plus this off-site repo.

---

## Possible Future Improvements

- Migrate PIA connection from OpenVPN to WireGuard for lower overhead
- Add Tautulli for Plex viewing statistics
- Cleanup automation (auto-delete watched media past a retention window)
- A UPS with `nut` for graceful shutdown on power loss

---

*Built as a learning project — every component was configured, debugged, and documented hands-on.*
