#!/usr/bin/env bash
# Downloads the model weights for the selected preset into the ComfyUI models dir
# (which start.sh has symlinked onto the persistent Network Volume).
#
# Idempotent: a file that already exists on the volume is skipped, so restarting a
# pod is fast. Failures are non-fatal — ComfyUI still starts and you can retry / use
# ComfyUI-Manager. Re-run any time with:  bash /provisioning.sh
#
# Env:
#   MODEL_PRESET    ltx23 (default) | ltx097
#   GEMMA_VARIANT   fp8_scaled (default) | full | fpmixed | fp4_mixed   [ltx23 only]
#   LTX097_UPSCALERS  true|false (default false)                        [ltx097 only]
#   HF_TOKEN        optional — only needed if a repo is gated / for higher rate limits
set -uo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
MODELS="$COMFYUI_DIR/models"
PRESET="${MODEL_PRESET:-ltx23}"
GEMMA_VARIANT="${GEMMA_VARIANT:-fp8_scaled}"
HF="https://huggingface.co"

mkdir -p "$MODELS"/{checkpoints,diffusion_models,loras,text_encoders,vae,latent_upscale_models,upscale_models}

# dl <url> <dest_path> — resumable, parallel when aria2c is present, skips if present.
dl () {
    local url="$1" dest="$2"
    if [ -s "$dest" ]; then
        echo "  ✓ present: $(basename "$dest")"
        return 0
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

  *)
    echo "!! Unknown MODEL_PRESET='$PRESET'. Use 'ltx23' or 'ltx097'." >&2
    exit 1
    ;;
esac

echo "==> Provisioning complete for preset '$PRESET'."
