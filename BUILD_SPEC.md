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
| `cubiq/ComfyUI_essentials` | `SimpleMath+` and utility nodes the IC-LoRA workflows reference |
| `Fannovel16/ComfyUI-Frame-Interpolation` | optional RIFE/FILM |
| `ltdrdata/ComfyUI-Manager` | install/repair nodes from the UI |

**⚠️ kornia pin (critical).** `ComfyUI-LTXVideo` lists `kornia` **unpinned**; it resolves to
**0.8.3**, which removed `pad` / `is_powerof_two` / `find_next_powerof_two` from
`kornia.geometry.transform.pyramid`. That ImportError makes the **entire LTXVideo pack fail to
load** — every IC-LoRA node (`LTXICLoRALoaderModelOnly`, `LTXAddVideoICLoRAGuide`,
`GemmaAPITextEncode`, `LTXVTiledVAEDecode`, …) silently disappears and all workflows show
"missing nodes". Fix: pin **`kornia==0.8.2`** (installed last in the Dockerfile so nothing
overrides it). Verified on the live pod: with 0.8.2 the pack imports and the Union Control
(canny/depth), V2V, Motion-Track and Inpaint 2.3 workflows load with zero missing nodes.

Two *exotic* 2.3 examples need extra packs (not installed by default): T2V two-stage advanced
sampler needs `ClownSampler_Beta` (RES4LYF), and Outpaint needs `ImagePadForOutpaintTargetSize`.

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

---

# AnimateDiff / SD1.5 add-on (`cool2-with-upscale-and-interp` workflow)

A second, **independent** workflow this image also serves. Added 2026-06-19. Every URL below
was verified live (HF file tree + `curl -I`/blob fetch) by a fan-out verification pass and
double-checked by an independent skeptic agent. It runs **additively** alongside the LTX preset
(`INSTALL_ANIMATEDIFF=true` by default).

## 8. Custom nodes (✅ confirmed node→repo mapping)

Already in the image from the LTX build: VideoHelperSuite, controlnet_aux, ComfyUI_essentials,
Frame-Interpolation. **Added** for this workflow:

| Repo | cnr_id | Provides | Dep notes |
|---|---|---|---|
| `cubiq/ComfyUI_IPAdapter_plus` | comfyui_ipadapter_plus | `IPAdapter*`, `PrepImageForClipVision` | no pip deps |
| `jags111/efficiency-nodes-comfyui` | efficiency-nodes-comfyui | `Efficient Loader`, `KSampler (Efficient)`, `HighRes-Fix Script`, `*Stacker` | pulls `simpleeval`+`clip-interrogator` (floor pins, safe) |
| `Kosinkadink/ComfyUI-Advanced-ControlNet` | comfyui-advanced-controlnet | `ControlNetLoaderAdvanced` (deprecated alias of `ACN_…`, still registers) | no pip deps |
| `Kosinkadink/ComfyUI-AnimateDiff-Evolved` | comfyui-animatediff-evolved | `ADE_AnimateDiffLoaderWithContext`, `ADE_AnimateDiffLoRALoader`, `ADE_LoopedUniformContextOptions`, `ADE_PromptScheduling` | no pip deps |
| `WASasquatch/was-node-suite-comfyui` | was-ns | `Text Multiline`, `Upscale Model Loader` | **reqs SKIPPED** (see ⚠️) |
| `FizzleDorf/ComfyUI_FizzNodes` | comfyui_fizznodes | `BatchPromptSchedule` | numpy/pandas/numexpr (unpinned) |
| `M1kep/ComfyLiterals` | ComfyLiterals | `Float` | none (branch `master`) |
| `kijai/ComfyUI-KJNodes` | comfyui-kjnodes | `GetImageRangeFromBatch` | opencv-headless (coexists w/ controlnet_aux's full opencv) |
| `ssitu/ComfyUI_UltimateSDUpscale` | comfyui_ultimatesdupscale | `UltimateSDUpscale` | **git submodule** → clone `--recurse-submodules` |
| `rgthree/rgthree-comfy` | _(none)_ | `Fast Bypasser (rgthree)`, `Mute / Bypass Repeater (rgthree)` | empty reqs; frontend nodes |

**⚠️ WAS Node Suite deps skipped on purpose.** Its `requirements.txt` pulls `numba` (which can
silently **downgrade numpy** and break the rest of the stack), `rembg`/`onnxruntime`, and a
second opencv variant. The only two WAS nodes this workflow uses load fine on ComfyUI's base
deps, so the Dockerfile's pip loop skips the `was-node-suite-comfyui/` dir. Install its heavier
image-processing deps later via ComfyUI-Manager if ever needed.

**⚠️ UltimateSDUpscale submodule.** It vendors `Coyote-A/ultimate-upscale` at
`repositories/ultimate_sd_upscale`; without `--recurse-submodules` the node fails to import.

## 9. Model manifest — AnimateDiff add-on (all ✅ verified live)

`dl()` saves under the **dest** name, so a source file with a different name is renamed on
download (the "rename from" column).

| File (workflow expects) | HF/Civitai source (`/resolve/main/…` unless noted) | Size | ComfyUI dir | Rename from | Branch |
|---|---|---|---|---|---|
| `photonLCM_v10.safetensors` | `moonshotmillion/Photon_LCM_1.5` | 2.13 GB | `checkpoints` | — | active |
| `lcm-lora-sdv1-5.safetensors` | `latent-consistency/lcm-lora-sdv1-5` | 135 MB | `loras` | `pytorch_lora_weights.safetensors` | active |
| `sd15_t2v_beta.ckpt` | `wangfuyun/AnimateLCM` | 1.81 GB | `animatediff_models` | `AnimateLCM_sd15_t2v.ckpt` | active |
| `control_v11p_sd15_lineart_fp16.safetensors` | `comfyanonymous/ControlNet-v1-1_fp16_safetensors` | 723 MB | `controlnet` | — | **active** |
| `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | `h94/IP-Adapter` (`models/image_encoder/`) | 2.53 GB | `clip_vision` | `model.safetensors` | active |
| `ip-adapter-plus_sd15.safetensors` | `h94/IP-Adapter` (`models/`) | 98 MB | `ipadapter` | — | active |
| `4x_RealisticRescaler_100000_G.pth` | `gemasai/4x_RealisticRescaler_100000_G` | 134 MB | `upscale_models` | — | active |
| `control_v11p_sd15_softedge_fp16.safetensors` | `comfyanonymous/ControlNet-v1-1_fp16_safetensors` | 723 MB | `controlnet` | — | bypassed |
| `control_v11f1p_sd15_depth_fp16.safetensors` | `comfyanonymous/ControlNet-v1-1_fp16_safetensors` | 723 MB | `controlnet` | — | bypassed (**depth branch, default**) |
| `control_v11p_sd15_openpose.pth` | `lllyasviel/ControlNet-v1-1` | 1.45 GB | `controlnet` | — | bypassed |
| `controlnet_checkpoint.ckpt` | `crishhh/animatediff_controlnet` | 1.45 GB | `controlnet` | — | bypassed |
| `4x-AnimeSharp.pth` | `Kim2091/AnimeSharp` | 67 MB | `upscale_models` | — | bypassed |
| `control-lora-canny-rank256.safetensors` | `stabilityai/control-lora` (`control-LoRAs-rank256/`) | 774 MB | `controlnet` | — | bypassed (SDXL) |
| `control_sd15_depth.pth` *(legacy)* | `lllyasviel/ControlNet` (`models/`) | **5.71 GB** | `controlnet` | — | off (`ANIM_DEPTH_CONTROLNET=true`) — superseded by the fp16 depth above |
| `bubblingRings_v10.safetensors` | Civitai `api/download/models/371646` (modelId 331718) | 129 MB | `animatediff_motion_lora` | — | off (`CIVITAI_TOKEN`) |

**Runtime auto-downloads (not pre-staged):** `film_net_fp32.pt` (FILM VFI → from
`dajes/frame-interpolation-pytorch` v1.0.0 GH release, into
`custom_nodes/ComfyUI-Frame-Interpolation/ckpts/film/`); `depth_anything_vitl14.pth`,
`dw-ll_ucoco_384.onnx`, `yolox_l.onnx` (controlnet_aux → into its `ckpts/`). These back the
bypassed depth/pose preprocessors, so they only fetch if you enable those branches.

**Notes:** `photonLCM_v10` is an unofficial HF re-upload of Civitai "Photon - LCM" (model
306814) — fine for bytes; verify SHA256 if provenance matters. The IPAdapter CLIP-Vision must
come from **h94/IP-Adapter** (2.53 GB vision-only encoder), **not** the laion repo's 3.94 GB
full CLIP. The workflow's depth node now points to the 723 MB **fp16** depth CN (not the 5.7 GB
legacy `control_sd15_depth.pth`). Active path ≈ 7.6 GB; +optional ≈ 5.2 GB; +legacy depth 5.7 GB
only with `ANIM_DEPTH_CONTROLNET=true`.
