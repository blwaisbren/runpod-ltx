# LTX-2.3 Video-to-Video — RunPod ComfyUI Template

A one-click RunPod template that boots straight into **ComfyUI** wired for **LTX-2.3
control-to-video** workflows — **Canny-to-video**, **Depth-to-video**, and **Pose-to-video**
out of the box. Push the image once with GitHub Actions, point a RunPod template at it,
deploy, and you're generating.

The image stays small: ComfyUI + all required custom nodes are baked in, while the large
model weights download to a persistent **Network Volume** on first boot. Restart later and
the models are already there.

---

## What you get

- **ComfyUI** on port `8188` (RunPod HTTP proxy), auto-started on boot.
- **JupyterLab** on port `8888` for file management / a terminal (optional).
- The official Lightricks **LTX example workflows** pre-loaded into the ComfyUI *Workflows*
  sidebar — including `LTX-2.3_ICLoRA_Union_Control_Distilled.json` (the canny+depth+pose
  video-to-video workflow).
- All required custom nodes installed (LTXVideo, VideoHelperSuite, controlnet_aux,
  Video-Depth-Anything, Frame-Interpolation, Manager).
- A model **provisioning script** that downloads exactly the right, **link-verified** files
  for your chosen preset.
- **Bonus, in the same pod:** a legacy **SD1.5 / AnimateDiff** video workflow
  (`AnimateDiff-examples/cool2-with-upscale-and-interp.json`) with its full node + model set —
  AnimateLCM, IPAdapter, ControlNet stack, Ultimate SD Upscale, ESRGAN upscalers and FILM
  interpolation — all baked in and provisioned by default. See
  [the AnimateDiff section in workflows/README.md](workflows/README.md#sd15--animatediff-workflow-cool2).

## The two model presets

Set `MODEL_PRESET` as a template env var.

| Preset | Model | Control | Encoder | Disk | Min GPU | Use it when |
|---|---|---|---|---|---|---|
| **`ltx23`** (default) | LTX-2.3 22B | **Union** IC-LoRA = Canny **+** Depth **+** Pose in one | Gemma 3 (ungated repackage) | ~68 GB | **48 GB** (L40S / A6000); 80 GB ideal | You want the newest model and the exact "LTX 2.3" workflow you described |
| **`ltx097`** | LTX-Video 0.9.7 13B | **Separate** Canny / Depth IC-LoRAs | T5-XXL | ~21 GB | **24 GB** (RTX 4090) | You want a cheap 24 GB GPU and discrete canny/depth LoRAs |

> **About "LTX 2.3":** it's real — `Lightricks/LTX-2.3` (22B), a March-2026 update to LTX-2.
> One detail to know up front: 2.3 ships a **single Union control IC-LoRA** that does canny,
> depth *and* pose together (you pick the mode by which preprocessor you feed it) rather than
> separate canny/depth files. The older **0.9.7** line is the only one with truly *separate*
> canny and depth LoRAs — that's why it's the `ltx097` fallback. Full reasoning + every
> verified link is in [BUILD_SPEC.md](BUILD_SPEC.md).

## Also included: the SD1.5 / AnimateDiff workflow

The same image **also** runs a classic **SD1.5 + AnimateDiff** video pipeline (the
`cool2-with-upscale-and-interp` workflow): AnimateLCM motion + LCM checkpoint, IPAdapter style
transfer, a multi-ControlNet stack (lineart enabled; openpose / softedge / depth / AnimateDiff
CN staged but bypassed), an Ultimate-SD-Upscale + ESRGAN highres pass, and FILM frame
interpolation. Its 10 extra custom-node packs are baked in, and its ~8 GB active model set
(plus ~5 GB of optional bypassed-branch models) is provisioned **alongside** the LTX models by
default — so one pod serves both. Toggle it with `INSTALL_ANIMATEDIFF` (see env table). Usage:
[workflows/README.md → AnimateDiff](workflows/README.md#sd15--animatediff-workflow-cool2).

---

## Quick start

### 1. Build & push the image (GitHub Actions → GHCR)

1. Create a GitHub repo and push this folder to it.
2. The workflow in [`.github/workflows/build-push.yml`](.github/workflows/build-push.yml)
   runs on every push to `main` and on `v*` tags. No secrets needed — it uses the built-in
   `GITHUB_TOKEN` to push to **GHCR** (`ghcr.io/blwaisbren/runpod-ltx`).
3. After the first build, open your repo → **Packages**, click the package → **Package
   settings** → set visibility to **Public** so RunPod can pull without credentials.
4. (Optional) Tag a release for a stable, pinned image:
   ```bash
   git tag v1.0.0 && git push origin v1.0.0
   ```

Prefer Docker Hub? See the commented block at the bottom of the workflow file.

### 2. Create the RunPod template

In the RunPod console → **Templates → New Template**. Exact field values are in
[`runpod/TEMPLATE.md`](runpod/TEMPLATE.md). The essentials:

- **Container Image:** `ghcr.io/blwaisbren/runpod-ltx:latest` (or your `v1.0.0` tag)
- **Container Disk:** 25 GB
- **Volume Disk / Network Volume:** attach a **150 GB+** Network Volume mounted at `/workspace`
- **Expose HTTP Ports:** `8188,8888`
- **Expose TCP Ports:** `22`
- **Env:** `MODEL_PRESET=ltx23` (plus the optional vars in the table below)

### 3. Deploy & open

1. **Create a Network Volume first** (Storage → Network Volume, ≥150 GB) in a region that has
   48 GB+ GPUs, then deploy a Pod from your template **onto that volume**.
2. First boot downloads ~68 GB of models — watch progress in the pod **Logs** (10–40 min
   depending on region). Subsequent boots skip downloads.
3. Open ComfyUI: **Connect → HTTP 8188**, i.e. `https://<POD_ID>-8188.proxy.runpod.net`.

### 4. Run a canny/depth video-to-video

In ComfyUI, open the **Workflows** sidebar → `LTX-examples/2.3/` →
**`LTX-2.3_ICLoRA_Union_Control_Distilled.json`**. Then:

- Load your **driving video** in the `Load Video` node.
- For **depth**: use the Depth-Anything branch. For **canny**: use the Canny preprocessor
  branch. (The Union workflow contains both — enable the one you want.)
- Write your prompt, set resolution so **width & height are each divisible by 64**, and queue.

Full per-mode notes: [`workflows/README.md`](workflows/README.md).

---

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `MODEL_PRESET` | `ltx23` | `ltx23` / `ltx097` — LTX set to download (`none` = skip LTX, AnimateDiff only) |
| `GEMMA_VARIANT` | `fp8_scaled` | `ltx23` encoder precision: `full` / `fpmixed` / `fp8_scaled` / `fp4_mixed` |
| `LTX097_UPSCALERS` | `false` | `ltx097`: also fetch the 0.9.7 spatial/temporal upscalers |
| `INSTALL_ANIMATEDIFF` | `true` | Download the SD1.5/AnimateDiff model set (additive to the LTX preset) |
| `ANIM_OPTIONAL_MODELS` | `true` | Also stage the **bypassed** control branches (openpose/softedge/**depth fp16**/etc.) |
| `ANIM_DEPTH_CONTROLNET` | `false` | Fetch the *legacy* 5.7 GB `control_sd15_depth.pth` (the 723 MB fp16 depth is already default) |
| `CIVITAI_TOKEN` | _(empty)_ | Needed only for the `bubblingRings` Civitai motion LoRA |
| `SKIP_PROVISIONING` | `false` | `true` = don't download models (you'll manage them yourself) |
| `ENABLE_JUPYTER` | `true` | Start JupyterLab on `:8888` |
| `JUPYTER_TOKEN` | _(empty)_ | Token to protect JupyterLab (recommended if exposed) |
| `COMFY_EXTRA_ARGS` | _(empty)_ | Passed to ComfyUI, e.g. `--lowvram`, `--reserve-vram 2`, `--fast` |
| `HF_TOKEN` | _(empty)_ | Only needed if a repo becomes gated / for higher download rate limits |
| `WORKSPACE` | `/workspace` | Network Volume mount point |

> All the files in the default `ltx23` preset download from **public** repos, so `HF_TOKEN`
> is **not required**. Set it only if you hit rate limits or a repo later requires license
> acceptance.

## GPU & VRAM guidance

LTX-2.3 22B is a big model. Disk is ~46 GB for the checkpoint alone; the encoder adds 8–23 GB.

| GPU | VRAM | `ltx23` (22B) | `ltx097` (13B) |
|---|---|---|---|
| RTX 4090 | 24 GB | Tight — use `fp4_mixed` encoder + `--lowvram`; short clips | ✅ comfortable |
| L40S / A6000 | 48 GB | ✅ recommended floor | ✅ |
| A100 / H100 | 80 GB | ✅ full quality, longer clips, hi-res | ✅ |
| RTX 5090 / Blackwell | 32 GB | Use fp8/nvfp4 path; CUDA 12.8 base supports it | ✅ |

Published per-resolution VRAM floors for 22B don't exist yet — validate on your rented GPU
and lower resolution / `GEMMA_VARIANT` if you OOM.

## Repo layout

```
.
├── Dockerfile                     # ComfyUI + custom nodes (no models)
├── scripts/
│   ├── start.sh                   # entrypoint: volume symlinks → provisioning → ComfyUI
│   └── provisioning.sh            # downloads the verified model set per preset
├── .github/workflows/build-push.yml   # CI → GHCR (Docker Hub alt included)
├── runpod/TEMPLATE.md             # exact RunPod template + pod field values
├── workflows/
│   ├── README.md                  # which workflow to load; LTX canny/depth + AnimateDiff notes
│   └── animatediff/               # the SD1.5/AnimateDiff workflow JSON (baked into the image)
├── BUILD_SPEC.md                  # verified research: every model, link, decision, risk
└── .env.example                   # copy to .env for local docker-compose testing
```

## Troubleshooting

- **Red / missing nodes on workflow load** → open **ComfyUI-Manager → Install Missing Custom
  Nodes**, then restart. (All required nodes are baked in, but Manager repairs anything that
  failed its build-time pip step.)
- **Encoder not found in the dropdown** → the workflow expects `comfy_gemma_3_12B_it.safetensors`;
  provisioning creates that as an alias to whatever `GEMMA_VARIANT` you chose. If you skipped
  provisioning, pick the real `gemma_3_12B_it_*.safetensors` file in the CLIP/encoder loader.
- **First depth run pauses** → the `video_depth_anything_vits.pth` model auto-downloads once.
- **Long jobs time out in the browser** → RunPod's HTTP proxy can drop ~100s idle connections;
  ComfyUI uses a websocket queue so generation continues — just don't close the tab abruptly.
- **Out of memory** → smaller resolution, `GEMMA_VARIANT=fp4_mixed`, `COMFY_EXTRA_ARGS=--lowvram`,
  or move to a larger GPU.

## Local test (optional)

With an NVIDIA GPU + Docker:
```bash
docker build -t comfyui-ltx .
docker run --rm --gpus all -p 8188:8188 -p 8888:8888 \
  -v $PWD/workspace:/workspace -e MODEL_PRESET=ltx23 comfyui-ltx
```
