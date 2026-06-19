# CLAUDE.md — project context & runbook

Context for future Claude sessions working in this repo. Also serves as the running log.

## What this is
A one-click **RunPod ComfyUI template for LTX-2.3 video-to-video** (Canny / Depth / Pose
via the Union IC-LoRA). Thin image (ComfyUI + custom nodes, no weights) → models download to a
RunPod Network Volume on first boot. Full reasoning + verified model links: [BUILD_SPEC.md](BUILD_SPEC.md).
Deploy field values: [runpod/TEMPLATE.md](runpod/TEMPLATE.md). Workflow usage: [workflows/README.md](workflows/README.md).

**Also serves a legacy SD1.5 / AnimateDiff workflow** (`workflows/animatediff/cool2-with-upscale-and-interp.json`)
from the SAME image — 10 extra node packs + a ~8 GB SD1.5 model set, provisioned **additively**
alongside LTX by default (`INSTALL_ANIMATEDIFF=true`). Manifest + verified links in BUILD_SPEC §8–9.

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
- **WAS Node Suite deps (AnimateDiff add-on):** WAS's `requirements.txt` pulls `numba` (can silently
  **downgrade numpy** → breaks the stack) + `rembg`/`onnxruntime` + a 2nd opencv. Dockerfile's pip loop
  **skips `was-node-suite-comfyui/`**; its 2 used nodes (Text Multiline, Upscale Model Loader) run on base deps.
- **UltimateSDUpscale submodule:** `ssitu/ComfyUI_UltimateSDUpscale` vendors `Coyote-A/ultimate-upscale`
  at `repositories/ultimate_sd_upscale` → cloned with `--recurse-submodules` or the node won't import.
- **AnimateDiff filename renames:** 3 source files differ from what the workflow expects — `dl()` saves under
  the dest name so it renames on download: `pytorch_lora_weights→lcm-lora-sdv1-5`, `AnimateLCM_sd15_t2v.ckpt→sd15_t2v_beta.ckpt`,
  IPAdapter `image_encoder/model.safetensors→CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`.
- **2 opt-in AnimateDiff models:** `bubblingRings_v10` is Civitai-gated (needs `CIVITAI_TOKEN`); the 5.7 GB legacy
  `control_sd15_depth.pth` is off unless `ANIM_DEPTH_CONTROLNET=true`. Both back **bypassed** nodes, so default-off is safe.

## Status / TODO
- ✅ Deployed and verified end-to-end. Union Control (canny/depth), V2V, Motion-Track, Inpaint 2.3 workflows
  load with zero missing nodes after the kornia fix.
- ✅ **AnimateDiff add-on deployed & verified end-to-end (2026-06-19).** Pushed → GHCR built clean →
  redeployed `comfyui-ltx23` (same `ltx-volume`, `MODEL_PRESET=ltx23` auto-installs the add-on). On the pod,
  `AnimateDiff-examples/cool2-...json` loads with **0 missing nodes** (89 nodes) and renders end-to-end:
  AnimateDiff → Ultimate SD Upscale → FILM interpolation all produced output. Both LTX-2.3 and the SD1.5/
  AnimateDiff workflow now run from the one image. (Opt-ins still untested live: `CIVITAI_TOKEN` bubblingRings
  LoRA + `ANIM_DEPTH_CONTROLNET` depth CN — both back bypassed nodes so not on the default path.)
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
- **2026-06-19:** Added support for the user's SD1.5/AnimateDiff workflow (`cool2-with-upscale-and-interp`)
  to the SAME image. Parsed the workflow → 14 node packs (4 already present) + 18 model files. Ran a fan-out
  verification workflow (one agent per model + per node pack, each fetching the live HF/Civitai/GitHub source,
  with an independent skeptic re-checking every model URL) → all verified high-confidence. Wired the 10 new
  node packs into the Dockerfile (WAS reqs skipped re numpy; UltimateSDUpscale `--recurse-submodules`), added
  an additive `provision_animatediff` block (default-on, with `ANIM_OPTIONAL_MODELS`/`ANIM_DEPTH_CONTROLNET`/
  `CIVITAI_TOKEN` flags + Civitai-token support in `dl()`), bundled the workflow JSON into the image and
  surfaced it in the sidebar via start.sh, and documented everything (BUILD_SPEC §8–9, README, TEMPLATE,
  workflows/README). Pushed (commit `18ca961`) → GHCR build succeeded → redeployed → **verified live on the
  pod: the workflow loads with 0 missing nodes and renders+upscales+interpolates end-to-end.** Done.
