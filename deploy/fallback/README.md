# Fastest Zero-Cost Fallback

If Oracle Always Free does not work, the fastest zero-cash fallback is:

`your current machine + Cloudflare Quick Tunnel`

That gives you:

- a public URL
- no Oracle account dependency
- no router port-forwarding
- no DNS setup
- the same local OBLITERATUS UI and `/v1/*` API you already have

It does **not** give you external CPU. The compute still runs on your machine.

## Windows

Run:

```powershell
.\deploy\fallback\start-local-public.ps1
```

That script:

- starts `app.py` on `localhost:8080` if it is not already running
- installs `cloudflared` with `winget` if needed
- opens a Quick Tunnel to the local server

## Linux / macOS

Run:

```bash
bash deploy/fallback/start-local-public.sh
```

You need `cloudflared` installed first on non-Windows systems.

## What you get

Cloudflare will print a random `https://...trycloudflare.com` URL that forwards to:

- `http://localhost:8080/`
- `http://localhost:8080/v1/models`
- `http://localhost:8080/v1/chat/completions`

## Constraints

Quick Tunnel is for testing/development, not production. Cloudflare documents:

- random `trycloudflare.com` subdomain
- testing/development only
- hard limit of `200` in-flight requests
- no SSE support

That last point matters because streaming chat responses over SSE are not a good fit for Quick Tunnel.
