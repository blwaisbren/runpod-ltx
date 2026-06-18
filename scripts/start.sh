#!/usr/bin/env bash
# Entrypoint for the LTX-2.3 ComfyUI RunPod template.
#   1. Persist models/user/output/input on the Network Volume (/workspace) via symlinks
#   2. Download models on first boot (idempotent) — see provisioning.sh
#   3. Surface the LTX example workflows in the ComfyUI sidebar
#   4. Start JupyterLab (optional) + ComfyUI
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/ComfyUI}"
WORKSPACE="${WORKSPACE:-/workspace}"

echo "=================================================================="
echo " LTX-2.3 ComfyUI template booting"
echo "   COMFYUI_DIR = $COMFYUI_DIR"
echo "   WORKSPACE   = $WORKSPACE   (RunPod Network Volume mount)"
echo "   MODEL_PRESET= ${MODEL_PRESET:-ltx23}"
echo "=================================================================="

mkdir -p "$WORKSPACE"

# --- Keep code in the image, keep heavy/stateful dirs on the persistent volume ---
# Migrate any baked content once, then replace the in-image dir with a symlink to the volume.
link_to_volume () {
    local name="$1"
    local target="$WORKSPACE/$name"
    local link="$COMFYUI_DIR/$name"
    mkdir -p "$target"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        cp -an "$link/." "$target/" 2>/dev/null || true
        rm -rf "$link"
    fi
    [ -L "$link" ] || ln -s "$target" "$link"
}
for d in models output input user; do
    link_to_volume "$d"
done

# --- Download models (idempotent). Set SKIP_PROVISIONING=true to skip. ---
if [ "${SKIP_PROVISIONING:-false}" != "true" ]; then
    echo "==> Running provisioning (first boot may take 10-40 min while models download)"
    bash /provisioning.sh || echo "WARNING: provisioning reported errors; starting ComfyUI anyway"
else
    echo "==> SKIP_PROVISIONING=true — not downloading models"
fi

# --- Make the LTX example workflows show up in the ComfyUI 'Workflows' sidebar ---
WF_SRC="$COMFYUI_DIR/custom_nodes/ComfyUI-LTXVideo/example_workflows"
WF_DST="$COMFYUI_DIR/user/default/workflows/LTX-examples"
if [ -d "$WF_SRC" ]; then
    mkdir -p "$WF_DST"
    cp -rn "$WF_SRC/." "$WF_DST/" 2>/dev/null || true
    echo "==> LTX example workflows copied to the ComfyUI Workflows sidebar"
fi

# --- Optional JupyterLab on :8888 ---
if [ "${ENABLE_JUPYTER:-true}" = "true" ]; then
    echo "==> Starting JupyterLab on :8888 (token='${JUPYTER_TOKEN:-<empty>}')"
    jupyter lab --allow-root --no-browser --ip=0.0.0.0 --port=8888 \
        --ServerApp.token="${JUPYTER_TOKEN:-}" --ServerApp.password='' \
        --notebook-dir="$WORKSPACE" >/var/log/jupyter.log 2>&1 &
fi

# --- Launch ComfyUI on :8188 (foreground) ---
cd "$COMFYUI_DIR"
echo "==> Starting ComfyUI on :8188"
echo "    Open it at: https://<POD_ID>-8188.proxy.runpod.net"
# COMFY_EXTRA_ARGS examples: --lowvram | --reserve-vram 2 | --fast | --use-sage-attention
exec python main.py --listen 0.0.0.0 --port 8188 ${COMFY_EXTRA_ARGS:-}
