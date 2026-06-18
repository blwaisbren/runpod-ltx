# ComfyUI + LTX-2.3 video-to-video (Canny / Depth / Pose IC-LoRA) — RunPod template image.
#
# Design: the IMAGE ships ComfyUI + all required custom nodes (versioned by image tag).
# The big model weights are NOT baked in — they download to a persistent RunPod
# Network Volume on first boot via /provisioning.sh. This keeps the image small
# (~8-12 GB) and lets you swap model presets without rebuilding.
#
# Base: RunPod's official PyTorch image (Torch 2.8 + CUDA 12.8.1, good for Ada/Blackwell
# and the LTX fp8 path). Tag confirmed to exist on Docker Hub.
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    HF_HUB_ENABLE_HF_TRANSFER=0 \
    COMFYUI_DIR=/ComfyUI \
    WORKSPACE=/workspace

# --- System dependencies ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        git git-lfs wget curl aria2 ffmpeg libgl1 libglib2.0-0 \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

# --- ComfyUI core ---
# Pin to a specific commit/tag by overriding COMFYUI_REF at build time for reproducibility.
ARG COMFYUI_REF=master
RUN git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}" \
    && cd "${COMFYUI_DIR}" \
    && git checkout "${COMFYUI_REF}" \
    && pip install --no-cache-dir -r requirements.txt

# --- Custom nodes required for the LTX-2.3 Union control workflow ---
#   ComfyUI-Manager           : install/repair nodes from the UI
#   ComfyUI-LTXVideo          : LTX core + IC-LoRA loaders (iclora.py) + Gemma encoder
#   ComfyUI-VideoHelperSuite  : LoadVideo / CreateVideo / SaveVideo (VHS_* nodes)
#   comfyui_controlnet_aux    : CannyEdgePreprocessor + DWPreprocessor (pose) + DepthAnythingV2
#   ComfyUI-Video-Depth-Anything : LoadVideoDepthAnythingModel + VideoDepthAnythingProcess
#   ComfyUI-Frame-Interpolation  : optional RIFE/FILM smoothing
WORKDIR ${COMFYUI_DIR}/custom_nodes
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone --depth 1 https://github.com/yuvraj108c/ComfyUI-Video-Depth-Anything.git && \
    git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# Install each node's Python deps. Tolerant (|| true) so a single noisy node
# (e.g. controlnet_aux's optional extras) can't fail the whole build — ComfyUI-Manager
# can repair anything missing at runtime.
RUN for d in */ ; do \
        if [ -f "${d}requirements.txt" ]; then \
            echo "==> pip install for ${d}"; \
            pip install --no-cache-dir -r "${d}requirements.txt" || echo "WARN: deps for ${d} had issues"; \
        fi; \
    done

# --- JupyterLab (optional file browser / terminal on :8888) ---
RUN pip install --no-cache-dir jupyterlab

# --- Entrypoint + provisioning scripts ---
WORKDIR /
COPY scripts/start.sh /start.sh
COPY scripts/provisioning.sh /provisioning.sh
RUN chmod +x /start.sh /provisioning.sh

# 8188 = ComfyUI, 8888 = JupyterLab
EXPOSE 8188 8888

CMD ["/start.sh"]
