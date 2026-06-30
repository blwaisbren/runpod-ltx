#!/usr/bin/env bash
# Downloads the model weights for the selected preset into the ComfyUI models dir
# (which start.sh has symlinked onto the persistent Network Volume).
#
# Idempotent: a file that already exists on the volume is skipped, so restarting a
# pod is fast. Failures are non-fatal — ComfyUI still starts and you can retry / use
# ComfyUI-Manager. Re-run any time with:  bash /provisioning.sh
#
# Env:
#   MODEL_PRESET     ltx23 (default) | ltx097 | none|animatediff (skip the LTX set)
#   GEMMA_VARIANT    fp8_scaled (default) | full | fpmixed | fp4_mixed    [ltx23 only]
#   LTX097_UPSCALERS true|false (default false)                          [ltx097 only]
#   INSTALL_ANIMATEDIFF   true (default) | false — the SD1.5/AnimateDiff model set (additive)
#   ANIM_OPTIONAL_MODELS  true (default) | false — also stage the BYPASSED control branches
#   ANIM_DEPTH_CONTROLNET false (default) | true — the heavy 5.7 GB legacy control_sd15_depth.pth
#   CIVITAI_TOKEN    optional — needed only for the bubblingRings Civitai motion LoRA
#   HF_TOKEN         optional — only needed if a repo is gated / for higher rate limits
set -uo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
MODELS="$COMFYUI_DIR/models"
PRESET="${MODEL_PRESET:-ltx23}"
GEMMA_VARIANT="${GEMMA_VARIANT:-fp8_scaled}"
HF="https://huggingface.co"

mkdir -p "$MODELS"/{checkpoints,diffusion_models,loras,text_encoders,vae,latent_upscale_models,upscale_models,controlnet,clip_vision,ipadapter,animatediff_models,animatediff_motion_lora}

# dl <url> <dest_path> — resumable, parallel when aria2c is present, skips if present.
dl () {
    local url="$1" dest="$2"
    if [ -s "$dest" ]; then
        echo "  ✓ present: $(basename "$dest")"
        return 0
    fi
    # Civitai download endpoints are token-gated — append the API token as a query param.
    if [[ "$url" == *civitai.com* ]] && [ -n "${CIVITAI_TOKEN:-}" ]; then
        if [[ "$url" == *\?* ]]; then url="${url}&token=${CIVITAI_TOKEN}"; else url="${url}?token=${CIVITAI_TOKEN}"; fi
    fi
    echo "  ↓ downloading: $(basename "$dest")"
    mkdir -p "$(dirname "$dest")"
    # Build the optional auth header as an array so spaces don't word-split the args.
    local hdr=()
    if [ -n "${HF_TOKEN:-}" ] && [[ "$url" == *huggingface.co* ]]; then
        hdr=(--header "Authorization: Bearer ${HF_TOKEN}")
    fi
    if command -v aria2c >/dev/null 2>&1; then
        if aria2c -x16 -s16 -k1M --console-log-level=warn --summary-interval=0 \
            --allow-overwrite=true --auto-file-renaming=false "${hdr[@]+"${hdr[@]}"}" \
            -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url"; then
            return 0
        fi
        echo "    aria2c failed — falling back to wget"
    fi
    if wget -c "${hdr[@]+"${hdr[@]}"}" -O "$dest" "$url"; then
        return 0
    fi
    echo "    !! FAILED: $url"
    rm -f "$dest"
    return 1
}

# Models for the legacy SD1.5 / AnimateDiff workflow (workflows/animatediff/cool2-...json).
# Filenames here MATCH the names baked into that workflow so every loader dropdown resolves.
# A few HF source files have different names than the workflow expects — dl() saves under the
# DEST basename, so passing the source URL + the target path renames them on download.
provision_animatediff () {
    echo "==> AnimateDiff/SD1.5 add-on — models for the 'cool2 upscale+interp' workflow"
    local CN="$MODELS/controlnet" CK="$MODELS/checkpoints" LO="$MODELS/loras"
    local AM="$MODELS/animatediff_models" AML="$MODELS/animatediff_motion_lora"
    local CV="$MODELS/clip_vision" IP="$MODELS/ipadapter" UP="$MODELS/upscale_models"

    # --- ACTIVE path (what the workflow runs on Queue) ---
    dl "$HF/moonshotmillion/Photon_LCM_1.5/resolve/main/photonLCM_v10.safetensors" \
       "$CK/photonLCM_v10.safetensors"                                    # SD1.5 LCM checkpoint (Baked VAE)
    dl "$HF/latent-consistency/lcm-lora-sdv1-5/resolve/main/pytorch_lora_weights.safetensors" \
       "$LO/lcm-lora-sdv1-5.safetensors"                                  # rename: pytorch_lora_weights -> lcm-lora
    dl "$HF/wangfuyun/AnimateLCM/resolve/main/AnimateLCM_sd15_t2v.ckpt" \
       "$AM/sd15_t2v_beta.ckpt"                                           # rename: AnimateLCM motion module
    dl "$HF/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_lineart_fp16.safetensors" \
       "$CN/control_v11p_sd15_lineart_fp16.safetensors"                   # the ENABLED control branch (lineart)
    dl "$HF/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
       "$CV/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"                  # rename: IPAdapter CLIP-Vision (ViT-H)
    dl "$HF/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors" \
       "$IP/ip-adapter-plus_sd15.safetensors"
    dl "$HF/gemasai/4x_RealisticRescaler_100000_G/resolve/main/4x_RealisticRescaler_100000_G.pth" \
       "$UP/4x_RealisticRescaler_100000_G.pth"                            # WAS Upscale Model Loader (active)

    # --- Models for the '4morph-ad2' workflow (IPAdapter-batch + QRCode-ControlNet variant,
    #     also bundled in this dir) — shares most of the set above, plus: ---
    dl "$HF/monster-labs/control_v1p_sd15_qrcode_monster/resolve/main/v2/control_v1p_sd15_qrcode_monster_v2.safetensors" \
       "$CN/qrCodeMonster_v20.safetensors"                                # rename: …_v2.safetensors -> qrCodeMonster_v20
    dl "$HF/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.ckpt" \
       "$MODELS/vae/vae-ft-mse-840000-ema-pruned.ckpt"
    # 4morph-ad2's AnimateDiff loader expects the motion module under its ORIGINAL filename
    # (unlike cool2, which expects it renamed to sd15_t2v_beta.ckpt) — alias rather than
    # re-download the same 1.81 GB file twice.
    ln -sf "sd15_t2v_beta.ckpt" "$AM/AnimateLCM_sd15_t2v.ckpt"
    # Its CheckpointLoaderSimple is repointed at photonLCM_v10.safetensors (already provisioned
    # above) instead of the workflow's original realismBYSTABLEYOGI_v6LCMNSFW.safetensors — an
    # NSFW-tagged Civitai checkpoint we couldn't confidently pin a download URL for.

    # --- OPTIONAL: models for the BYPASSED control/highres branches (so dropdowns resolve;
    #     enable the branch in the UI to use them). Skip with ANIM_OPTIONAL_MODELS=false. ---
    if [ "${ANIM_OPTIONAL_MODELS:-true}" = "true" ]; then
        dl "$HF/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11p_sd15_softedge_fp16.safetensors" \
           "$CN/control_v11p_sd15_softedge_fp16.safetensors"
        dl "$HF/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1p_sd15_depth_fp16.safetensors" \
           "$CN/control_v11f1p_sd15_depth_fp16.safetensors"               # modern depth CN (723 MB) — workflow default
        dl "$HF/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth" \
           "$CN/control_v11p_sd15_openpose.pth"
        dl "$HF/crishhh/animatediff_controlnet/resolve/main/controlnet_checkpoint.ckpt" \
           "$CN/controlnet_checkpoint.ckpt"
        dl "$HF/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth" \
           "$UP/4x-AnimeSharp.pth"
        dl "$HF/stabilityai/control-lora/resolve/main/control-LoRAs-rank256/control-lora-canny-rank256.safetensors" \
           "$CN/control-lora-canny-rank256.safetensors"                   # SDXL Control-LoRA used by HighRes-Fix
    fi

    # --- LEGACY optional: the old 5.7 GB v1.0 full depth ControlNet (`control_sd15_depth.pth`).
    #     The modern 723 MB depth CN above is now the workflow default; this is only for graphs
    #     still pinned to the old filename. Off unless ANIM_DEPTH_CONTROLNET=true. ---
    if [ "${ANIM_DEPTH_CONTROLNET:-false}" = "true" ]; then
        dl "$HF/lllyasviel/ControlNet/resolve/main/models/control_sd15_depth.pth" \
           "$CN/control_sd15_depth.pth"
    else
        echo "  ⓘ skipping legacy control_sd15_depth.pth (5.7 GB) — modern depth CN is default; set ANIM_DEPTH_CONTROLNET=true for the old file"
    fi

    # --- Civitai motion LoRA (token-gated). Fetched only when CIVITAI_TOKEN is set. ---
    if [ -n "${CIVITAI_TOKEN:-}" ]; then
        dl "https://civitai.com/api/download/models/371646" \
           "$AML/bubblingRings_v10.safetensors"
    else
        echo "  ⓘ skipping bubblingRings_v10.safetensors — set CIVITAI_TOKEN to fetch the Civitai motion LoRA"
    fi

    echo "==> AnimateDiff add-on done. (FILM interpolation, DWPose & Depth-Anything models"
    echo "    auto-download into the custom-node ckpts dirs on first use of those branches.)"
}

case "$PRESET" in
  ltx23)
    echo "==> Preset ltx23 — LTX-2.3 (22B), Union IC-LoRA (Canny + Depth + Pose)"
    # Base checkpoint (VAE is bundled inside this file — no separate VAE needed)
    dl "$HF/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-dev.safetensors" \
       "$MODELS/checkpoints/ltx-2.3-22b-dev.safetensors"
    # Some loaders look in diffusion_models/ — expose the same file there too (no extra disk)
    ln -sf "../checkpoints/ltx-2.3-22b-dev.safetensors" \
       "$MODELS/diffusion_models/ltx-2.3-22b-dev.safetensors"

    # Distilled adapter (8-step speed) — the Union workflow applies this on top of dev
    dl "$HF/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-lora-384-1.1.safetensors" \
       "$MODELS/loras/ltx-2.3-22b-distilled-lora-384-1.1.safetensors"

    # The control IC-LoRA — Canny + Depth + Pose in one checkpoint
    dl "$HF/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors" \
       "$MODELS/loras/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"

    # Optional two-stage hi-res upscalers (latent_upscale_models for LTX-2 nodes)
    dl "$HF/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors" \
       "$MODELS/latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.1.safetensors"
    dl "$HF/Lightricks/LTX-2.3/resolve/main/ltx-2.3-temporal-upscaler-x2-1.0.safetensors" \
       "$MODELS/latent_upscale_models/ltx-2.3-temporal-upscaler-x2-1.0.safetensors"

    # Gemma 3 text encoder — Comfy-Org's ungated ComfyUI repackage (no Google license gate)
    case "$GEMMA_VARIANT" in
        full)      gfile=gemma_3_12B_it.safetensors ;;          # ~22.7 GB, best quality
        fpmixed)   gfile=gemma_3_12B_it_fpmixed.safetensors ;;  # ~12.8 GB
        fp4_mixed) gfile=gemma_3_12B_it_fp4_mixed.safetensors ;;# ~8.8 GB, lowest VRAM
        *)         gfile=gemma_3_12B_it_fp8_scaled.safetensors ;;# ~12.3 GB (default)
    esac
    dl "$HF/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/$gfile" \
       "$MODELS/text_encoders/$gfile"
    # The shipped Union workflow references this exact name — alias it so it loads as-is.
    ln -sf "$gfile" "$MODELS/text_encoders/comfy_gemma_3_12B_it.safetensors"

    echo "==> ltx23 done. Note: the depth model (video_depth_anything_vits.pth) is"
    echo "    auto-downloaded by the Video-Depth-Anything node the first time you run depth."
    ;;

  ltx097)
    echo "==> Preset ltx097 — LTX-Video 0.9.7 (13B), separate Canny + Depth, T5 (24GB-friendly)"
    # Base checkpoint, fp8 (VAE bundled). Swap to ltxv-13b-0.9.7-dev.safetensors (28.6 GB) for bf16.
    dl "$HF/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.7-dev-fp8.safetensors" \
       "$MODELS/checkpoints/ltxv-13b-0.9.7-dev-fp8.safetensors"

    # T5-XXL text encoder (fp8 scaled ~5 GB). Use t5xxl_fp16.safetensors (9.8 GB) for max quality.
    dl "$HF/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors" \
       "$MODELS/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors"

    # Separate Canny + Depth IC-LoRAs (use the -comfyui variant, NOT -diffusers)
    dl "$HF/Lightricks/LTX-Video-ICLoRA-canny-13b-0.9.7/resolve/main/ltxv-097-ic-lora-canny-control-comfyui.safetensors" \
       "$MODELS/loras/ltxv-097-ic-lora-canny-control-comfyui.safetensors"
    dl "$HF/Lightricks/LTX-Video-ICLoRA-depth-13b-0.9.7/resolve/main/ltxv-097-ic-lora-depth-control-comfyui.safetensors" \
       "$MODELS/loras/ltxv-097-ic-lora-depth-control-comfyui.safetensors"

    if [ "${LTX097_UPSCALERS:-false}" = "true" ]; then
        dl "$HF/Lightricks/LTX-Video/resolve/main/ltxv-spatial-upscaler-0.9.7.safetensors" \
           "$MODELS/upscale_models/ltxv-spatial-upscaler-0.9.7.safetensors"
        dl "$HF/Lightricks/LTX-Video/resolve/main/ltxv-temporal-upscaler-0.9.7.safetensors" \
           "$MODELS/upscale_models/ltxv-temporal-upscaler-0.9.7.safetensors"
    fi
    ;;

  none|animatediff)
    echo "==> MODEL_PRESET='$PRESET' — skipping the LTX model set (AnimateDiff add-on below)."
    ;;

  *)
    echo "!! Unknown MODEL_PRESET='$PRESET'. Use 'ltx23', 'ltx097', or 'none'." >&2
    exit 1
    ;;
esac

# --- AnimateDiff / SD1.5 add-on (ADDITIVE) — runs alongside the LTX preset by default so a
#     single pod serves BOTH the LTX-2.3 workflows and the cool2 AnimateDiff workflow. ---
if [ "${INSTALL_ANIMATEDIFF:-true}" = "true" ]; then
    provision_animatediff
else
    echo "==> INSTALL_ANIMATEDIFF=false — skipping the AnimateDiff/SD1.5 model set."
fi

echo "==> Provisioning complete (preset '$PRESET', animatediff=${INSTALL_ANIMATEDIFF:-true})."
