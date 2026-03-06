# Google Cloud Setup

This repo now has a Compute Engine deployment path for OBLITERATUS.

Best fit on Google Cloud:

- **Free control-plane path:** `e2-micro`
- **Actually usable CPU path:** `e2-standard-4`

Why two paths:

- the Compute Engine Free Tier currently includes:
  - `1` non-preemptible `e2-micro` VM per month
  - only in `us-central1`, `us-east1`, or `us-west1`
  - `30 GB-months` standard persistent disk
  - `1 GB` outbound transfer from North America per month
- `e2-micro` is fine for:
  - the web UI shell
  - the `/v1` API surface
  - light orchestration
- `e2-micro` is **not** a good fit for real model work
- if you still have trial credits, use `e2-standard-4` instead
  - Google documents `e2-standard-4` as `4 vCPU / 16 GB RAM`

## Files

- bootstrap on the VM: [bootstrap.sh](/d:/obliterate/obliterateee/deploy/gcp/bootstrap.sh)
- metadata startup script for GCE: [startup-script.sh](/d:/obliterate/obliterateee/deploy/gcp/startup-script.sh)
- local Windows helper to create the VM with `gcloud`: [create-vm.ps1](/d:/obliterate/obliterateee/deploy/gcp/create-vm.ps1)

## Fastest path from your Windows machine

1. Install Google Cloud CLI.
2. Authenticate:

```powershell
gcloud auth login
gcloud auth application-default login
```

3. Create the VM from this repo:

Free-tier shell:

```powershell
.\deploy\gcp\create-vm.ps1 -ProjectId YOUR_PROJECT_ID -InstanceName obliteratus -Zone us-central1-a -MachineType e2-micro -DiskSizeGb 30
```

Practical CPU path with credits:

```powershell
.\deploy\gcp\create-vm.ps1 -ProjectId YOUR_PROJECT_ID -InstanceName obliteratus -Zone us-central1-a -MachineType e2-standard-4 -DiskSizeGb 50
```

That script:

- creates an HTTP firewall rule if needed
- creates the VM
- passes the startup script through instance metadata
- clones this repo on the VM
- installs CPU-safe dependencies
- starts `obliteratus ui`
- exposes the app through nginx on port `80`

## Check bootstrap progress

```powershell
gcloud compute instances get-serial-port-output obliteratus --zone us-central1-a --port 1
```

## Get the public IP

```powershell
gcloud compute instances describe obliteratus --zone us-central1-a --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
```

Then open:

```text
http://PUBLIC_IP/
http://PUBLIC_IP/v1/models
http://PUBLIC_IP/v1/chat/completions
```

## Manual bootstrap on an existing VM

SSH in, then:

```bash
git clone https://github.com/gsfit1996/obliterateee.git
cd obliterateee
sudo REPO_URL=https://github.com/gsfit1996/obliterateee.git \
     REPO_REF=main \
     APP_USER=obliteratus \
     APP_DIR=/opt/obliteratus \
     APP_PORT=8080 \
     ENABLE_NGINX=1 \
     bash deploy/gcp/bootstrap.sh
```

## Logs on the VM

```bash
sudo journalctl -u obliteratus -n 100 --no-pager
tail -n 100 /opt/obliteratus/logs/obliteratus.log
tail -n 100 /opt/obliteratus/logs/obliteratus.err.log
tail -n 100 /var/log/obliteratus-startup.log
```

## Recommendation

If the goal is "maximum optionality on Google Cloud":

1. start with `e2-standard-4` while you still have credits
2. if you want to minimize spend later, shrink to `e2-micro` and use it as a public control plane only
3. keep the local Cloudflare fallback as your zero-cost backstop

## Official docs used

- Compute Engine free tier
- Compute Engine machine types
- startup scripts
- instance metadata
- firewall rules
- static IPs
- Ops Agent
