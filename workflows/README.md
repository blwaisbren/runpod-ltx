# Workflows — canny / depth / pose video-to-video

The official Lightricks example workflows are baked into the image (inside the
`ComfyUI-LTXVideo` custom node) and copied into the ComfyUI **Workflows** sidebar on boot at
`LTX-examples/`. You don't need to download anything — just open them in the UI.

## `ltx23` preset (default) — the one you asked for

**Open:** Workflows sidebar → `LTX-examples/2.3/` → **`LTX-2.3_ICLoRA_Union_Control_Distilled.json`**

This single workflow does **canny-, depth- and pose-to-video** using the Union control
IC-LoRA. It loads:

| Slot | File (provisioned for you) |
|---|---|
| Checkpoint | `ltx-2.3-22b-dev.safetensors` |
| Speed LoRA | `ltx-2.3-22b-distilled-lora-384-1.1.safetensors` |
| Control LoRA | `ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors` |
| Text encoder | `comfy_gemma_3_12B_it.safetensors` (alias → your `GEMMA_VARIANT`) |

**How to drive it:**
1. **`Load Video`** (VideoHelperSuite) — your driving/reference clip.
2. Pick the control branch:
   - **Canny** → the `CannyEdgePreprocessor` branch.
   - **Depth** → the `LoadVideoDepthAnythingModel` + `VideoDepthAnythingProcess` branch
     (its model auto-downloads the first time).
   - **Pose** → the `DWPreprocessor` branch.
3. **Reference rules (important):** the Union LoRA uses a 0.5× reference downscale, and the
   reference video **width & height must each be divisible by 64**. Keep your output
   resolution on a 64-grid too (e.g. 768×512, 1280×704).
4. Set your text prompt, frame count, and **Queue**.

Other useful 2.3 workflows in the same folder: `LTX-2.3_V2V_ICLoRA_Single_Stage_Distilled.json`
(simpler v2v), `LTX-2.3_T2V_I2V_Single_Stage_Distilled_Full.json` (text/image-to-video),
plus inpaint / outpaint / motion-track / lipdub variants.

## `ltx097` preset — separate canny & depth

**Open:** Workflows sidebar → `LTX-examples/` (the 0.9.x IC-LoRA examples).

Here canny and depth are **separate** LoRAs — load the one you want:
- Canny: `ltxv-097-ic-lora-canny-control-comfyui.safetensors`
- Depth: `ltxv-097-ic-lora-depth-control-comfyui.safetensors`

with checkpoint `ltxv-13b-0.9.7-dev-fp8.safetensors` and encoder
`t5xxl_fp8_e4m3fn_scaled.safetensors`. **Use the `-comfyui` LoRA files, not `-diffusers`.**

## SD1.5 / AnimateDiff workflow (cool2)

This image **also** bundles a legacy **SD1.5 + AnimateDiff** video pipeline, independent of the
LTX presets. It's surfaced in the sidebar at
**Workflows → `AnimateDiff-examples/` → `cool2-with-upscale-and-interp.json`**.

It runs on **AnimateLCM** (low-step LCM motion) with IPAdapter style transfer, a ControlNet
stack, an Ultimate-SD-Upscale + ESRGAN highres pass, and FILM frame interpolation. It's SD1.5,
so it's **light on VRAM** — any 8 GB+ GPU is plenty (it'll run fine on whatever GPU you rented
for LTX).

**Models (provisioned by default via `INSTALL_ANIMATEDIFF=true`):**

| Slot | File | Branch |
|---|---|---|
| Checkpoint | `photonLCM_v10.safetensors` (Baked VAE) | active |
| LCM LoRA | `lcm-lora-sdv1-5.safetensors` | active |
| Motion module | `sd15_t2v_beta.ckpt` (AnimateLCM) | active |
| ControlNet | `control_v11p_sd15_lineart_fp16.safetensors` | active |
| IPAdapter | `ip-adapter-plus_sd15.safetensors` + `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | active |
| Upscaler | `4x_RealisticRescaler_100000_G.pth` | active |
| Interpolation | `film_net_fp32.pt` (auto-downloads on first run) | active |
| Optional CN | openpose `.pth`, softedge fp16, **depth fp16** (`control_v11f1p_sd15_depth_fp16`, 723 MB), `controlnet_checkpoint.ckpt`, `4x-AnimeSharp.pth`, SDXL `control-lora-canny-rank256` | **bypassed** (staged so dropdowns resolve) |
| Legacy depth | `control_sd15_depth.pth` (5.7 GB old format) | off — set `ANIM_DEPTH_CONTROLNET=true` (the fp16 depth above is the default) |
| Motion LoRA | `bubblingRings_v10.safetensors` (Civitai) | off — set `CIVITAI_TOKEN` |

**How to drive it:**
1. `Load Image` / the video-load nodes — your driving frames.
2. The **lineart** ControlNet branch is enabled by default; the openpose/softedge/depth and
   AnimateDiff-CN branches are **bypassed** — un-bypass (Ctrl-B) any whose model is staged.
3. Set prompts in the `Efficient Loader` / `BatchPromptSchedule` nodes; LCM likes **~4–8 steps**.
4. The HighRes-Fix / Ultimate SD Upscale + FILM interpolation tail is wired up; **Queue**.

> **Opt-in extras.** Everything (including the 723 MB fp16 depth ControlNet) is fetched
> automatically from public HuggingFace repos — **except** `bubblingRings_v10.safetensors` (a
> Civitai motion LoRA, used by a bypassed node), which needs a **`CIVITAI_TOKEN`**. The old
> 5.7 GB `control_sd15_depth.pth` is no longer used by the workflow; set
> **`ANIM_DEPTH_CONTROLNET=true`** only if you specifically need that legacy file.

## 4morph-ad2 workflow

A 3rd bundled workflow, also under **Workflows → `AnimateDiff-examples/` → `4morph-ad2.json`**.
Same AnimateDiff/SD1.5 family as `cool2`, but driven by **3 chained `IPAdapterBatch`** nodes for
style transfer and a **QRCode-Monster ControlNet** reading motion off a black-and-white mask
video, rendering a 4-frame "morph". An **`UltimateSDUpscale`** group and a **`FILM VFI`**
interpolation group are appended after the render — they're present but **only loosely wired**;
finish connecting them in the ComfyUI canvas before queueing.

**Models:** reuses most of `cool2`'s set (`lcm-lora-sdv1-5.safetensors`,
`4x_RealisticRescaler_100000_G.pth`, the AnimateLCM motion module — aliased under its original
filename) plus three new ones fetched automatically: `qrCodeMonster_v20.safetensors` (ControlNet),
`vae-ft-mse-840000-ema-pruned.ckpt` (VAE), and the checkpoint
`realismBYSTABLEYOGI_v4LCM.safetensors` (a v4 LCM "Realism by Stable Yogi" SD1.5 checkpoint —
the workflow's original `realismBYSTABLEYOGI_v6LCMNSFW.safetensors` was an NSFW Civitai upload we
couldn't confidently source, so this is a close, verified-reachable HF substitute from the same
uploader as `photonLCM_v10`). Everything is provisioned by default — nothing to fetch by hand.
See BUILD_SPEC.md §10 for the full manifest.

## Tips

- **Missing/red nodes?** ComfyUI-Manager → *Install Missing Custom Nodes* → restart.
- **Saving your own workflows** persists to `/workspace/user/...` on the Network Volume, so
  they survive pod restarts.
- The canonical, always-current versions of these workflows live in the node repo:
  <https://github.com/Lightricks/ComfyUI-LTXVideo/tree/master/example_workflows>
