# CLAUDE.md — project context & runbook

Context for future Claude sessions working in this repo. Also serves as the running log.

## What this is
A one-click **RunPod ComfyUI template for LTX-2.3 video-to-video** (Canny / Depth / Pose
via the Union IC-LoRA). Thin image (ComfyUI + custom nodes, no weights) → models download to a
RunPod Network Volume on first boot. Full reasoning + verified model links: [BUILD_SPEC.md](BUILD_SPEC.md).
Deploy field values: [runpod/TEMPLATE.md](runpod/TEMPLATE.md). Workflow usage: [workflows/README.md](workflows/README.md).

## Live resources (as of 2026-06-18)
- **GitHub:** `blwaisbren/runpod-ltx` (public) — push to `main` auto-builds via GitHub Actions.
- **Image:** `ghcr.io/blwaisbren/runpod-ltx:latest` (GHCR package is **public** so RunPod pulls without creds).
- **RunPod template:** `comfyui-ltx23` (id `7dvorxi420`) — ports 8188/8888, mount `/workspace`, env `MODEL_PRESET=ltx23`.
- **Network volume:** `ltx-volume` (150 GB, **EU-RO-1**, id `1azydc12v8`) — holds the ~68 GB model set.
- **First pod:** `cute_apricot_snake` (id `cmhl42uccqeodu`), RTX PRO 6000 96 GB, ~$2.09/hr.

## Deploy / use
1. Pods → Deploy → select `ltx-volume` (locks region to EU-RO-1) → pick a **48 GB+ GPU** → template `comfyui-ltx23`.
2. First boot downloads models (~10 min in EU-RO-1). Open ComfyUI on the **8188** HTTP service.
3. ComfyUI → Workflows → `LTX-examples/2.3/LTX-2.3_ICLoRA_Union_Control_Distilled.json` → load driving video,
   enable Canny or Depth branch, keep W/H divisible by 64, Queue.
4. **Stop the pod when idle** — $2.09/hr; the volume + models persist so restarts are fast.

## Gotchas (hard-won — don't re-derive)
- **kornia pin (critical):** `ComfyUI-LTXVideo` lists kornia unpinned → resolves to **0.8.3**, which dropped
  `pad`/`is_powerof_two`/`find_next_powerof_two` from `kornia.geometry.transform.pyramid` → the WHOLE
  LTXVideo pack fails to import → all IC-LoRA nodes silently missing → every workflow shows "missing nodes".
  Dockerfile pins **`kornia==0.8.2`** (installed LAST) + adds `cubiq/ComfyUI_essentials` (SimpleMath+).
- **RunPod proxy 403 in browser:** `*-8188.proxy.runpod.net` gates on a per-subdomain auth cookie; hitting it
  before the service is ready caches a 403. Fix: incognito, or clear that subdomain's site-data. (Normal-browser
  access still TODO.)
- **Diagnosing the pod:** RunPod Connect tab → enable **Web terminal**; or anonymously from anywhere:
  `curl https://<podid>-8188.proxy.runpod.net/object_info` (returns the live node list).

## Status / TODO
- ✅ Deployed and verified end-to-end. Union Control (canny/depth), V2V, Motion-Track, Inpaint 2.3 workflows
  load with zero missing nodes after the kornia fix.
- ⬜ Normal-browser (non-incognito) proxy access — clear cookie / proper login handshake.
- ⬜ Optional: add `RES4LYF` (`ClownSampler_Beta`) + an `ImagePadForOutpaintTargetSize` provider to make the
  T2V-two-stage and Outpaint examples turnkey too (not needed for canny/depth).
- 🗓️ Built for a lecture ~July 2026 — tear down `ltx-volume` afterward to stop the ~$10/mo storage charge.

## Session log
- **2026-06-18:** Researched LTX-2.3 stack (verified every HF model link), scaffolded the repo, built+pushed
  the GHCR image, created the RunPod template via browser, deployed onto `ltx-volume`, downloaded all models.
  Hit two issues and fixed both: (1) browser proxy 403 = stale per-subdomain cookie (incognito works);
  (2) all LTX IC-LoRA nodes missing = kornia 0.8.3 ImportError → pinned `kornia==0.8.2` + added
  `comfyui_essentials`, fixed live on the pod and baked into the image.
