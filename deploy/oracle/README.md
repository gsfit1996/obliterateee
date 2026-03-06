# Oracle Always Free Setup

This path targets the most flexible free external host for OBLITERATUS:

- OCI `VM.Standard.A1.Flex`
- Ubuntu image
- CPU-only deployment
- `obliteratus ui` exposed through nginx on port `80`
- local OpenRouter-compatible API exposed at `/v1/*`

## Why this setup

Oracle Always Free currently includes:

- up to `4 OCPUs`
- up to `24 GB` RAM total on Ampere A1
- `200 GB` block volume storage

That is enough for:

- the Gradio UI
- the local `/v1/chat/completions` API
- small-model CPU chat
- background caching and saved liberated models

It is not a good fit for smooth 7B/8B interactive CPU inference.

## Important constraint

The Always Free shape with the most optionality is Arm-based. This repo's default
requirements include `bitsandbytes`, which is not needed for CPU hosting and can
be painful on Arm. The bootstrap therefore uses [requirements.cpu.txt](/d:/obliterate/obliterateee/requirements.cpu.txt)
plus `pip install --no-deps -e .`.

## Console steps

1. Create an Oracle Cloud account and choose a home region.
2. Create a compute instance in that home region.
3. Pick `VM.Standard.A1.Flex`.
4. Allocate as much of the free pool as you can:
   - `4 OCPUs`
   - `24 GB` memory
5. Use an Ubuntu image.
6. Give the boot volume at least `50 GB`.
7. In networking, allow inbound:
   - `22/tcp` for SSH
   - `80/tcp` for nginx
   - optionally `8080/tcp` if you want to bypass nginx during debugging
8. SSH into the instance.

Oracle documents:

- Always Free resources
- instance launch
- initialization scripts through `Advanced Options`

## Bootstrap

Clone your repo and run the bootstrap as root or via `sudo`:

```bash
git clone https://github.com/gsfit1996/obliterateee.git
cd obliterateee
sudo REPO_URL=https://github.com/gsfit1996/obliterateee.git \
     REPO_REF=main \
     APP_USER=ubuntu \
     APP_DIR=/opt/obliteratus \
     APP_PORT=8080 \
     ENABLE_NGINX=1 \
     bash deploy/oracle/bootstrap.sh
```

If your Oracle image user is `opc` instead of `ubuntu`, change `APP_USER`.

## What the bootstrap does

- installs system packages
- clones or updates the repo into `/opt/obliteratus`
- creates a venv
- installs CPU-safe dependencies
- installs the package editable
- creates `obliteratus.service`
- starts `obliteratus ui --host 127.0.0.1 --port 8080 --no-browser`
- configures nginx on port `80`

## Check it

```bash
sudo systemctl status obliteratus --no-pager
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1/
```

From your laptop:

```bash
curl http://YOUR_ORACLE_PUBLIC_IP/v1/models
```

## Update it later

```bash
cd /opt/obliteratus
sudo -u ubuntu git pull --ff-only
sudo systemctl restart obliteratus
```

## Logs

```bash
sudo journalctl -u obliteratus -n 100 --no-pager
tail -n 100 /opt/obliteratus/logs/obliteratus.log
tail -n 100 /opt/obliteratus/logs/obliteratus.err.log
```

## If Oracle capacity is unavailable

Use the zero-cost fallback in [deploy/fallback/README.md](/d:/obliterate/obliterateee/deploy/fallback/README.md).
