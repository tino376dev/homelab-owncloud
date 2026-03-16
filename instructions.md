# Self‑Hosted Photo Backup on Raspberry Pi (Behind Mobile Hotspot)

This guide describes how to host a private cloud on a Raspberry Pi that is
connected to the internet via a **smartphone hotspot** and make it reachable at:

https://owncloud.mydomain.com

The solution works **without port forwarding**, **behind CGNAT**, and supports
automatic photo backups from mobile phones.

---

## Architecture Overview

```text
Phone (Nextcloud App)
        │
        ▼
Cloudflare (DNS + TLS + Tunnel)
        │
        ▼
Raspberry Pi (Nextcloud + local storage)
```

Key idea:

- The Raspberry Pi establishes an **outbound tunnel** to Cloudflare
- No inbound ports are required
- Fully HTTPS with your own domain

---

## Requirements

### Hardware

- Raspberry Pi 4 (4 GB+) or Raspberry Pi 5
- USB SSD (strongly recommended, not SD card)
- Stable power supply

### Software

- Raspberry Pi OS Lite (or Fedora IoT / Debian)
- Docker + Docker Compose
- Cloudflare account
- A domain name (`mydomain.com`)

### Phone

- Nextcloud App (iOS or Android)

---

## Step 1: Configure Cloudflare for Your Domain

1. Move your domain’s DNS to Cloudflare
2. Verify the domain is active in the Cloudflare dashboard
3. No A / AAAA records are needed for your Pi

---

## Step 2: Create a Cloudflare Tunnel

On your Pi:

```bash
docker run --rm -it cloudflare/cloudflared tunnel login
```

This opens a browser login and authorizes Cloudflare.

Create the tunnel:

```bash
cloudflared tunnel create nextcloud
```

Note the **Tunnel ID**.

---

## Step 3: DNS Record for Nextcloud

In Cloudflare:

- Create a DNS record:
  - Type: `CNAME`
  - Name: `owncloud`
  - Target: `<TUNNEL_ID>.cfargotunnel.com`
  - Proxy: **Enabled (orange cloud)**

---

## Step 4: Run Nextcloud (Docker)

Create a directory structure:

```bash
mkdir -p ~/nextcloud/{html,data}
cd ~/nextcloud
```

`docker-compose.yml`:

```yaml
version: "3.8"

services:
  nextcloud:
    image: nextcloud:apache
    container_name: nextcloud
    volumes:
      - ./html:/var/www/html
      - ./data:/var/www/html/data
    environment:
      - NEXTCLOUD_TRUSTED_DOMAINS=owncloud.mydomain.com
    restart: unless-stopped
```

Start Nextcloud:

```bash
docker compose up -d
```

---

## Step 5: Run Cloudflare Tunnel

Create a tunnel config:

```bash
mkdir -p ~/.cloudflared
```

`~/.cloudflared/config.yml`:

```yaml
tunnel: nextcloud
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: owncloud.mydomain.com
    service: http://nextcloud:80
  - service: http_status:404
```

Run the tunnel via Docker:

```bash
docker run -d \
  --name cloudflared \
  --network host \
  -v ~/.cloudflared:/root/.cloudflared \
  cloudflare/cloudflared:latest \
  tunnel run nextcloud
```

---

## Step 6: Initial Nextcloud Setup

Open in a browser:

```
https://owncloud.mydomain.com
```

- Create admin account
- Choose `/var/www/html/data` for data directory
- Skip external database for small installs (SQLite is fine)

---

## Step 7: Phone Photo Backup

1. Install **Nextcloud App**
2. Log in to:
   ```
   https://owncloud.mydomain.com
   ```
3. Enable:
   - ✅ Auto Upload
   - ✅ Wi‑Fi only (recommended)
   - ✅ Upload while charging

Photos will automatically back up to your Raspberry Pi.

---

## Security Recommendations

- Enable **2‑Factor Authentication** in Nextcloud
- Keep Docker images updated
- Enable Cloudflare:
  - HTTPS only
  - Rate limiting
  - Bot protection
- Do **not** expose SSH publicly

---

## Storage & Reliability Notes

- Use a **USB SSD** (SD cards wear out quickly)
- Consider:
  - Nightly rsync backup to another disk
  - Periodic off‑Pi backup

---

## Why This Works Well on a Mobile Hotspot

- No port forwarding
- No static IP required
- Survives IP changes
- Automatic TLS
- Reconnects transparently

---

## Summary

✅ Public URL with your domain\
✅ Works behind CGNAT / hotspot\
✅ Secure by default\
✅ Excellent mobile photo backup experience

**Recommended stack:**\
**Nextcloud + Cloudflare Tunnel + Raspberry Pi + USB SSD**
