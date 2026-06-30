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
**Plus a 3rd workflow** (`workflows/animatediff/4morph-ad2.json`, added 2026-06-30) in the same
dir/node-pack family — IPAdapter-batch + QRCode-Monster ControlNet + user-appended (loosely wired)
upscale/interp groups. One extra node pack (ComfyUI-Crystools) + 3 extra models (incl. its
checkpoint, `realismBYSTABLEYOGI_v4LCM.safetensors` — a verified HF substitute for the workflow's
original NSFW/Civitai checkpoint), manifest in BUILD_SPEC §10.

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
- **Browser 403 = ComfyUI CSRF, NOT a RunPod cookie (corrected 2026-06-19):** the "Access denied / HTTP 403"
  page is **ComfyUI's own `origin_only_middleware`** (server.py) rejecting requests the browser tags
  `Sec-Fetch-Site: cross-site` or where `Origin != Host`. The RunPod proxy itself is **public/unauthenticated**
  (gated only by the unguessable Pod ID — `console.runpod.io` login is on `runpod.io`, a *different* registrable
  domain than `proxy.runpod.net`, so it's never even sent there). Proof: a clean `curl …/object_info` returns
  **200**, but adding `-H 'Sec-Fetch-Site: cross-site'` returns **403** — and *only* that header flips it (none /
  same-origin / Referer / Origin / Cookie all still return 200). **CONFIRMED trigger (2026-06-19):** the browser
  sends `Sec-Fetch-Site: cross-site` only when you reach the pod by **clicking a link from another site — i.e.
  the RunPod dashboard's "Connect → :8188" button** (`console.runpod.io` → `proxy.runpod.net` is cross-site).
  Opening the URL by **typing/pasting it in the address bar, or from a bookmark, sends `Sec-Fetch-Site: none` →
  200**; a reload sends `same-origin` → 200. NOT extensions (verified live: disabling ALL extensions did not
  help) and NOT stored state (a full data-wipe didn't help) — incognito only "worked" because the URL gets
  pasted there. **Per-user fix (no redeploy):** paste the URL in the address bar / use a bookmark; don't click
  the dashboard Connect button. **Permanent fix (baked in):** start.sh now launches ComfyUI with
  `--enable-cors-header` by default (`COMFY_ENABLE_CORS=true`), removing the origin check so even the dashboard
  Connect button works.
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
- **Depth CN swapped to fp16 (2026-06-19):** the workflow's depth node was repointed from the 5.7 GB legacy
  `control_sd15_depth.pth` → the 723 MB `control_v11f1p_sd15_depth_fp16.safetensors` (comfyanonymous fp16 repo),
  now downloaded by default in the `ANIM_OPTIONAL_MODELS` set. `ANIM_DEPTH_CONTROLNET` is now legacy-only (off).
- **Remaining opt-in:** `bubblingRings_v10` is Civitai-gated (needs `CIVITAI_TOKEN`); it backs a **bypassed** node.

## Status / TODO
- ✅ Deployed and verified end-to-end. Union Control (canny/depth), V2V, Motion-Track, Inpaint 2.3 workflows
  load with zero missing nodes after the kornia fix.
- ✅ **AnimateDiff add-on deployed & verified end-to-end (2026-06-19).** Pushed → GHCR built clean →
  redeployed `comfyui-ltx23` (same `ltx-volume`, `MODEL_PRESET=ltx23` auto-installs the add-on). On the pod,
  `AnimateDiff-examples/cool2-...json` loads with **0 missing nodes** (89 nodes) and renders end-to-end:
  AnimateDiff → Ultimate SD Upscale → FILM interpolation all produced output. Both LTX-2.3 and the SD1.5/
  AnimateDiff workflow now run from the one image. **Follow-up (2026-06-19):** swapped the depth ControlNet to
  the 723 MB fp16 model (default-on) and repointed the workflow's depth node to it — pushed for rebuild.
  (Remaining opt-in untested live: `CIVITAI_TOKEN` bubblingRings LoRA — backs a bypassed node.)
- ✅ **Normal-browser (non-incognito) proxy access — FIXED & VERIFIED LIVE (2026-06-19).** Root cause was
  misdiagnosed as a "stale auth cookie"; it's actually ComfyUI's `origin_only_middleware` 403 on cross-site
  navigations, i.e. clicking the RunPod dashboard "Connect → ComfyUI" button (see gotcha above). start.sh now
  passes `--enable-cors-header` by default. GHCR build succeeded; user deployed a **fresh** pod from the
  template (a Stop→Start reuses the cached old image, so a fresh deploy is required) and confirmed the
  dashboard ComfyUI link now opens in normal Chrome with all extensions on — no incognito, no workaround.
- ⬜ Optional: add `RES4LYF` (`ClownSampler_Beta`) + an `ImagePadForOutpaintTargetSize` provider to make the
  T2V-two-stage and Outpaint examples turnkey too (not needed for canny/depth).
- ⬜ **`4morph-ad2.json` rolled into the image (2026-06-30), not yet deployed/verified live.** Bundled the
  workflow file, added `ComfyUI-Crystools` to the Dockerfile, and 2 new models to provisioning.sh
  (`qrCodeMonster_v20.safetensors`, `vae-ft-mse-840000-ema-pruned.ckpt`, both verified reachable via
  `curl -I`). Repointed the workflow's checkpoint node at `photonLCM_v10.safetensors` (already
  provisioned) instead of its original NSFW-tagged Civitai checkpoint, which we couldn't confidently
  source a URL for — confirmed by the user, fully resolved, nothing manual left to do model-wise.
  Pending: push → GHCR rebuild → fresh pod deploy → confirm 0 missing nodes. The user is still
  hand-wiring the `upscale`/`interp` groups onto the 4-morph render inside the pod.
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
- **2026-06-19 (later):** Swapped the workflow's depth ControlNet from the 5.7 GB legacy `control_sd15_depth.pth`
  → the 723 MB `control_v11f1p_sd15_depth_fp16.safetensors` (verified in comfyanonymous fp16 repo). Repointed
  node 78 + added it to the default `ANIM_OPTIONAL_MODELS` download set so it's present on every pod; demoted
  `ANIM_DEPTH_CONTROLNET` to a legacy-only opt-in. Committed (`a5dd876`) + pushed → GHCR rebuild. **Note on the
  cp -n gotcha:** start.sh copies the bundled workflow with `cp -rn`, so a volume that already has the old
  `AnimateDiff-examples/` copy keeps it on redeploy — delete that folder once (or re-pick node 78) to pick up
  the fp16-pointing JSON; the model itself downloads automatically regardless.
- **2026-06-19 (browser 403 fix):** User reported the pod's ComfyUI would only open in incognito — a normal
  Chrome profile 403'd even after wiping **all** Chrome data. Investigated live with the Chrome MCP + a
  terminal probe: clean `curl …/object_info` → **200** (pod healthy), but `-H 'Sec-Fetch-Site: cross-site'`
  → **403**, proving the 403 is **ComfyUI's `origin_only_middleware`**, not a RunPod auth cookie (the prior
  diagnosis was wrong — RunPod's proxy is public, and the console cookie is on a different registrable domain).
  First guessed a normal-profile **browser extension** was tagging the nav cross-site — but the user disabled
  ALL extensions and it still 403'd, **disproving that**. A curl matrix then nailed it: `Sec-Fetch-Site:
  cross-site` is the *only* header that flips 200→403. **CONFIRMED root trigger: the user was opening the pod via
  the RunPod dashboard's "Connect → :8188" button** — a `console.runpod.io` → `proxy.runpod.net` cross-site
  navigation. **Verified live:** pasting the same URL into the address bar (→ `Sec-Fetch-Site: none`) loaded
  ComfyUI in regular Chrome with all extensions ON. So incognito "worked" only because the URL was pasted there;
  data-wipe/extension theories were both red herrings. **Permanent fix:** start.sh now launches ComfyUI with
  `--enable-cors-header` by default (env `COMFY_ENABLE_CORS`, default `true`), removing the origin check so even
  the dashboard Connect button works. Corrected the gotcha + closed the standing TODO above. **Redeploy note:**
  this is an image change → needs a GHCR rebuild + pod redeploy to take effect; until then, the address-bar /
  bookmark workaround fully unblocks normal-browser use (no redeploy required). **Confirmed by comparison: a 2nd
  pod on a stock ComfyUI template returns 200 to a `Sec-Fetch-Site: cross-site` request where this template
  returned 403 — i.e. stock images already ship the relaxed check.** **✅ Verified end state:** GHCR build
  succeeded → user deployed a fresh pod from the template → the dashboard "ComfyUI" link now opens in normal
  Chrome (extensions on, no incognito). Done. (Reminder baked into the gotcha: Stop→Start reuses the cached old
  image; only a fresh deploy picks up image changes.)
- **2026-06-30:** User built a 3rd AnimateDiff-family workflow locally (`4morph-ad2.json` —
  IPAdapter-batch + QRCode-Monster ControlNet 4-frame morph, with `upscale`/`interp` groups
  appended but only loosely wired; user finishing that wiring on the pod). Rolled it into the
  image: bundled the JSON into `workflows/animatediff/` (auto-surfaces via the existing
  `cp -rn` copy in start.sh — no script change needed), diffed its node/model requirements
  against the existing manifest, and found it's almost entirely covered by what `cool2` already
  installs. Added one missing node pack (`crystian/ComfyUI-Crystools`, for the `Primitive integer
  [Crystools]` "Total Frames" node) to the Dockerfile. Noted but did NOT add `cg-use-everywhere`
  — the workflow JSON tags its `PrimitiveInt` node with that cnr_id, but `PrimitiveInt` is a core
  ComfyUI node (`comfy_extras/nodes_primitive.py`); the tag is stale copy-paste metadata, not a
  real dependency. Added 2 new models to provisioning.sh, both verified reachable via `curl -I`
  before adding: `qrCodeMonster_v20.safetensors` (renamed from monster-labs' `v2/…_v2.safetensors`,
  723 MB) and `vae-ft-mse-840000-ema-pruned.ckpt` (stabilityai's standard SD1.5 VAE, 335 MB). The
  workflow's AnimateDiff loader expects the motion module under its original filename
  (`AnimateLCM_sd15_t2v.ckpt`), unlike `cool2` which expects it renamed to `sd15_t2v_beta.ckpt` —
  aliased with a symlink instead of downloading the same 1.81 GB file twice. One model couldn't be
  safely auto-sourced: `realismBYSTABLEYOGI_v6LCMNSFW.safetensors` is an NSFW-tagged Civitai
  checkpoint; web search found several similarly-named "Realism by Stable Yogi" variants (Pony,
  Illustrious, SDXL) but no confident match for this exact SD1.5/LCM filename, so per policy
  against guessing URLs, flagged the gap instead of fetching it. **User follow-up:** confirmed
  fine to just drop the NSFW checkpoint — edited the bundled `4morph-ad2.json` itself (node 564,
  `CheckpointLoaderSimple`) to point at `photonLCM_v10.safetensors` (already provisioned for
  `cool2`), verified the JSON diff touches only that one widget value. Fully resolved — no manual
  step left. Updated BUILD_SPEC.md (§10), workflows/README.md, and this file.
  **Not yet pushed/deployed** — local repo changes only, pending user go-ahead to push (triggers
  GHCR rebuild) and redeploy a fresh pod to verify live.
- **2026-06-30 (later):** Pushed (`3bc513b`) → GHCR build succeeded (~9 min) → user deployed a
  fresh pod and confirmed `4morph-ad2.json` works. Follow-up: user asked for an actual "Realism by
  Stable Yogi" checkpoint instead of the `photonLCM_v10` fallback ("photon is fine but realism is
  peak"), specifically mentioning a v4 LCM variant. Found `realismBYSTABLEYOGI_v4LCM.safetensors`
  on HF under **`moonshotmillion`** — the same uploader this repo already trusts for
  `photonLCM_v10` — verified reachable + size (2.13 GB) via `curl -I` before adding. Added it to
  provisioning.sh and repointed the bundled workflow's `CheckpointLoaderSimple` (node 564) at it,
  same way as the `photonLCM_v10` swap. `photonLCM_v10` stays provisioned for `cool2`. Updated
  BUILD_SPEC §10, workflows/README.md, this file. Pending: push + rebuild + redeploy.
