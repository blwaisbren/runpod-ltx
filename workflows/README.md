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

## Tips

- **Missing/red nodes?** ComfyUI-Manager → *Install Missing Custom Nodes* → restart.
- **Saving your own workflows** persists to `/workspace/user/...` on the Network Volume, so
  they survive pod restarts.
- The canonical, always-current versions of these workflows live in the node repo:
  <https://github.com/Lightricks/ComfyUI-LTXVideo/tree/master/example_workflows>
