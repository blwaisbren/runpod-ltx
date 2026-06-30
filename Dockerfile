# ComfyUI for RunPod — serves BOTH the LTX-2.3 video-to-video (Canny/Depth/Pose IC-LoRA)
# workflows AND a legacy SD1.5 / AnimateDiff workflow (ControlNet + IPAdapter + Ultimate SD
# Upscale + FILM interpolation) from a single image.
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
#   ComfyUI_essentials        : SimpleMath+ and other utility nodes the LTX workflows use
#   ComfyUI-Frame-Interpolation  : optional RIFE/FILM smoothing
WORKDIR ${COMFYUI_DIR}/custom_nodes
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/Lightricks/ComfyUI-LTXVideo.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone --depth 1 https://github.com/yuvraj108c/ComfyUI-Video-Depth-Anything.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git

# --- Custom nodes for the legacy SD1.5 / AnimateDiff workflow (cool2 upscale+interp,
#     and the 4morph-ad2 IPAdapter-batch + QRCode-ControlNet variant) ---
#   ComfyUI_IPAdapter_plus       : IPAdapter* loaders/encoders + PrepImageForClipVision
#   efficiency-nodes-comfyui     : Efficient Loader, KSampler (Efficient), HighRes-Fix, *Stacker
#   ComfyUI-Advanced-ControlNet  : ControlNetLoaderAdvanced
#   ComfyUI-AnimateDiff-Evolved  : ADE_* motion loader / motion-LoRA / context / prompt-schedule
#   was-node-suite-comfyui       : Text Multiline, Upscale Model Loader (reqs SKIPPED below)
#   ComfyUI_FizzNodes            : BatchPromptSchedule
#   ComfyLiterals                : Float
#   ComfyUI-KJNodes              : GetImageRangeFromBatch
#   ComfyUI_UltimateSDUpscale    : UltimateSDUpscale (vendors a submodule — clone --recursive)
#   rgthree-comfy                : Fast Bypasser / Mute-Bypass Repeater (frontend nodes)
#   ComfyUI-Crystools            : "Primitive integer [Crystools]" (4morph-ad2's Total Frames node)
RUN git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && \
    git clone --depth 1 https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git && \
    git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    git clone --depth 1 https://github.com/FizzleDorf/ComfyUI_FizzNodes.git && \
    git clone --depth 1 https://github.com/M1kep/ComfyLiterals.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 --recurse-submodules https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/crystian/ComfyUI-Crystools.git

# Install each node's Python deps. Tolerant (|| true) so a single noisy node
# (e.g. controlnet_aux's optional extras) can't fail the whole build — ComfyUI-Manager
# can repair anything missing at runtime.
#
# We SKIP was-node-suite-comfyui's requirements on purpose: they pull numba (which can silently
# DOWNGRADE numpy and break the rest of the stack), rembg/onnxruntime, and a 2nd opencv variant.
# The only two WAS nodes this workflow uses — Text Multiline, Upscale Model Loader — load fine on
# ComfyUI's base deps (numpy / opencv-from-controlnet_aux / spandrel). Install WAS's heavier
# image-processing deps later via ComfyUI-Manager if you ever want them.
RUN for d in */ ; do \
        case "$d" in was-node-suite-comfyui/) echo "==> skipping bulk reqs for ${d} (avoids numpy downgrade)"; continue;; esac; \
        if [ -f "${d}requirements.txt" ]; then \
            echo "==> pip install for ${d}"; \
            pip install --no-cache-dir -r "${d}requirements.txt" || echo "WARN: deps for ${d} had issues"; \
        fi; \
    done

# Belt-and-suspenders: efficiency-nodes hard-imports simpleeval at load time (and its
# requirements.txt also drags in the heavier clip-interrogator). Guarantee simpleeval is present
# so a hiccup in that line above can't make all 6 efficiency nodes silently vanish.
RUN pip install --no-cache-dir simpleeval

# Pin kornia LAST so nothing overrides it. ComfyUI-LTXVideo lists kornia UNPINNED, which
# resolves to 0.8.3 — that release removed symbols the pack imports
# (pad / is_powerof_two / find_next_powerof_two from kornia.geometry.transform.pyramid),
# making the ENTIRE LTXVideo pack fail to import (all IC-LoRA nodes silently missing).
# 0.8.2 still exports them. Verified on the live pod.
RUN pip install --no-cache-dir "kornia==0.8.2"

# --- JupyterLab (optional file browser / terminal on :8888) ---
RUN pip install --no-cache-dir jupyterlab

# --- Entrypoint + provisioning scripts ---
WORKDIR /
COPY scripts/start.sh /start.sh
COPY scripts/provisioning.sh /provisioning.sh
RUN chmod +x /start.sh /provisioning.sh

# --- Bundled example workflow(s) surfaced in the ComfyUI sidebar by start.sh ---
# (The LTX examples ship inside the ComfyUI-LTXVideo node; these are the SD1.5/AnimateDiff ones:
#  cool2-with-upscale-and-interp.json and 4morph-ad2.json — everything in this dir is copied.)
COPY workflows/animatediff /workflows_bundled/animatediff

# 8188 = ComfyUI, 8888 = JupyterLab
EXPOSE 8188 8888

CMD ["/start.sh"]
