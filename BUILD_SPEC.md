# Build spec — LTX-2.3 canny/depth video-to-video on RunPod

Research + link verification behind this template. Every HuggingFace path marked ✅ was
confirmed by fetching the repo's file tree via the HuggingFace API (filename **and** size).

## 1. Version decision

**"LTX 2.3" is real** — `Lightricks/LTX-2.3` (22B), a March-2026 update to LTX-2 with better
audio/visual quality and prompt adherence. Lineage:

```
LTX-Video 2B (Nov 2024)
  → LTXV-13B 0.9.x (2025; 0.9.7 has separate canny/depth IC-LoRAs + T5)
    → LTX-2 19B (open weights Jan 2026; separate canny/depth IC-LoRAs)
      → LTX-2.3 22B (Mar 2026; single Union canny+depth+pose IC-LoRA)   ← TARGET
```

**Control situation (the crux):**
- **LTX-2.3** ships **one** Union-Control IC-LoRA = **Canny + Depth + Pose** in a single file.
  You select the mode by which preprocessor you feed it. → primary path (`ltx23`).
- **LTX-Video 0.9.7** is the only line with truly **separate** canny and depth LoRAs **and** a
  T5 encoder, and runs on 24 GB. → fallback path (`ltx097`).
- LTX-2 19B also has separate canny/depth LoRAs, but 2.3 is Lightricks' current primary line.

**Encoder:** LTX-2.3 uses **Gemma 3 12B**, not T5. The raw Google repo is gated, but
**Comfy-Org repackaged it ungated** (`Comfy-Org/ltx-2`), so no license/token is needed.

**Quantization:** official LTX-2.3 quants are **fp8** (`Lightricks/LTX-2.3-fp8`) and **nvfp4**
(`Lightricks/LTX-2.3-nvfp4`). There is **no official Q8/GGUF** for 2.3 — any such file is a
community conversion.

## 2. Model manifest — `ltx23` (primary), all ✅ verified

| File | Purpose | HF repo (path) | Size | ComfyUI dir |
|---|---|---|---|---|
| `ltx-2.3-22b-dev.safetensors` | base checkpoint (**VAE bundled**) | `Lightricks/LTX-2.3` | 46.1 GB | `checkpoints` |
| `ltx-2.3-22b-distilled-lora-384-1.1.safetensors` | 8-step speed adapter | `Lightricks/LTX-2.3` | 7.6 GB | `loras` |
| `ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors` | **Canny+Depth+Pose control** | `Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control` | 654 MB | `loras` |
| `ltx-2.3-spatial-upscaler-x2-1.1.safetensors` | hi-res (optional) | `Lightricks/LTX-2.3` | 996 MB | `latent_upscale_models` |
| `ltx-2.3-temporal-upscaler-x2-1.0.safetensors` | hi-res (optional) | `Lightricks/LTX-2.3` | 262 MB | `latent_upscale_models` |
| `gemma_3_12B_it_fp8_scaled.safetensors` | text encoder (default) | `Comfy-Org/ltx-2` (`split_files/text_encoders/`) | 12.3 GB | `text_encoders` |

Encoder alternatives in `Comfy-Org/ltx-2/split_files/text_encoders/` (all ✅):
`gemma_3_12B_it.safetensors` 22.7 GB · `gemma_3_12B_it_fpmixed.safetensors` 12.8 GB ·
`gemma_3_12B_it_fp4_mixed.safetensors` 8.8 GB.

- The Union workflow JSON references the encoder as **`comfy_gemma_3_12B_it.safetensors`** —
  provisioning downloads your chosen variant and symlinks that exact name to it.
- **VAE:** the workflow uses the checkpoint itself for VAE + audio VAE — **no separate VAE
  file** (resolves the earlier `taeltx2_3.safetensors` question — not needed).
- **Depth model:** `video_depth_anything_vits.pth` is auto-downloaded by the
  Video-Depth-Anything node on first depth run.

## 3. Model manifest — `ltx097` (fallback), all ✅ verified

| File | Purpose | HF repo | Size | ComfyUI dir |
|---|---|---|---|---|
| `ltxv-13b-0.9.7-dev-fp8.safetensors` | base (VAE bundled) | `Lightricks/LTX-Video` | 15.7 GB | `checkpoints` |
| `t5xxl_fp8_e4m3fn_scaled.safetensors` | text encoder | `comfyanonymous/flux_text_encoders` | 5.16 GB | `text_encoders` |
| `ltxv-097-ic-lora-canny-control-comfyui.safetensors` | **canny** | `Lightricks/LTX-Video-ICLoRA-canny-13b-0.9.7` | 82 MB | `loras` |
| `ltxv-097-ic-lora-depth-control-comfyui.safetensors` | **depth** | `Lightricks/LTX-Video-ICLoRA-depth-13b-0.9.7` | 82 MB | `loras` |
| `ltxv-spatial-upscaler-0.9.7.safetensors` | hi-res (opt) | `Lightricks/LTX-Video` | 505 MB | `upscale_models` |
| `ltxv-temporal-upscaler-0.9.7.safetensors` | hi-res (opt) | `Lightricks/LTX-Video` | 524 MB | `upscale_models` |

Each IC-LoRA repo also has a `-diffusers` variant — **use `-comfyui` in ComfyUI.**
`t5xxl_fp16.safetensors` (9.79 GB) is available in the same encoder repo for max quality.

## 4. Custom nodes (✅ confirmed node→package mapping)

| Repo | Provides |
|---|---|
| `Lightricks/ComfyUI-LTXVideo` | LTX core, IC-LoRA loaders (`iclora.py`), Gemma encoder (`gemma_encoder.py`), example workflows |
| `Kosinkadink/ComfyUI-VideoHelperSuite` | `VHS_*` LoadVideo / CreateVideo / SaveVideo |
| `Fannovel16/comfyui_controlnet_aux` | `CannyEdgePreprocessor`, `DWPreprocessor` (pose), `DepthAnythingV2Preprocessor` |
| `yuvraj108c/ComfyUI-Video-Depth-Anything` | `LoadVideoDepthAnythingModel`, `VideoDepthAnythingProcess` (depth branch of the 2.3 workflow) |
| `Fannovel16/ComfyUI-Frame-Interpolation` | optional RIFE/FILM |
| `ltdrdata/ComfyUI-Manager` | install/repair nodes from the UI |

Example workflows confirmed in `ComfyUI-LTXVideo/example_workflows/2.3/`:
`LTX-2.3_ICLoRA_Union_Control_Distilled.json` (canny+depth+pose),
`LTX-2.3_V2V_ICLoRA_Single_Stage_Distilled.json`, `..._T2V_I2V_...`, inpaint/outpaint/
motion-track/lipdub/HDR variants.

## 5. Deployment architecture

- **Image:** ships ComfyUI + nodes only (versioned by tag). Base
  `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` (✅ exists; Torch 2.8 +
  CUDA 12.8.1 covers Ada/Blackwell + fp8).
- **Models:** download to a **Network Volume** at `/workspace` on first boot via
  `provisioning.sh` (idempotent). Not baked in → small image, fast rebuilds, swappable presets.
- **Persistence:** `start.sh` symlinks `models/ output/ input/ user/` from the in-image
  ComfyUI to the volume, so models and saved workflows survive restarts while code stays in
  the image.
- **Ports:** 8188 ComfyUI (RunPod proxy `https://<POD_ID>-8188.proxy.runpod.net`), 8888 Jupyter.
- **GPU:** 48 GB floor for 22B (`ltx23`); 24 GB fine for `ltx097`. See README table.

## 6. CI/CD

GitHub Actions → GHCR (`docker/build-push-action@v6`, `cache-from/to: type=gha`, built-in
`GITHUB_TOKEN`, no extra secrets). Docker Hub alternative documented in the workflow file.
Make the GHCR package **public** so RunPod pulls without credentials. Pin image tags
(`:v1.0.0`) rather than `:latest`.

## 7. Open items / things to know

1. **Network Volume is DC-pinned** — create it in a region with 48 GB+ GPUs *before* deploying.
2. **22B VRAM floors aren't officially published** — validate on the rented GPU; drop
   resolution / `GEMMA_VARIANT` if you OOM.
3. **fp8 matmul needs Ada (RTX 40xx) or newer**; older cards fall back to slower paths.
4. **No official Q8/GGUF for 2.3** — fp8 / nvfp4 only (nvfp4 *distilled* was "coming soon" at
   research time).
5. **Encoder filename alias** — the workflow wants `comfy_gemma_3_12B_it.safetensors`;
   provisioning symlinks it. If you skip provisioning, pick the real `gemma_3_12B_it_*` file.
6. **`LTX-2-19b` base repo is gated (401)** — if you ever switch to the LTX-2 19B separate
   canny/depth path, you'll need an `HF_TOKEN` with the license accepted (the IC-LoRA repos
   themselves are public).
