# RunPod template — exact field values

Two steps in the RunPod console: **(A)** create a Network Volume, **(B)** create a Template,
then deploy a Pod from the template onto the volume.

---

## A. Network Volume (do this first)

**Storage → Network Volumes → New Network Volume**

| Field | Value | Notes |
|---|---|---|
| Name | `ltx-models` | anything |
| Data Center | pick one with **48 GB+ GPUs** | the volume is **pinned to this DC** and can't move |
| Size | **150 GB** | `ltx23` needs ~68 GB; 150 GB leaves room for a 2nd checkpoint / outputs |

> Why first: a Network Volume **must be attached when the Pod is created** and constrains
> which GPUs are available (same data center). Choosing the DC up front avoids "no GPU
> available" surprises.

---

## B. Template

**Templates → New Template**

| Field | Value |
|---|---|
| Template Name | `comfyui-ltx23` |
| Template Type | **Pod** (not Serverless) |
| Container Image | `ghcr.io/blwaisbren/runpod-ltx:latest` (or a pinned `:v1.0.0`) |
| Container Registry Credentials | _none_ if the GHCR package is **public** |
| Container Disk | `25` GB |
| Volume Disk | leave to Network Volume (below) |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `8188,8888` |
| Expose TCP Ports | `22` |
| Container Start Command | _(leave blank — the image's `CMD /start.sh` handles it)_ |

### Environment Variables

| Key | Value |
|---|---|
| `MODEL_PRESET` | `ltx23` |
| `GEMMA_VARIANT` | `fp8_scaled` |
| `INSTALL_ANIMATEDIFF` | `true` _(downloads the SD1.5/AnimateDiff model set alongside LTX)_ |
| `ANIM_OPTIONAL_MODELS` | `true` _(stage the bypassed control branches; `false` to skip ~4.5 GB)_ |
| `ANIM_DEPTH_CONTROLNET` | _(optional — `true` to fetch the heavy 5.7 GB legacy depth CN)_ |
| `CIVITAI_TOKEN` | _(optional — only for the bubblingRings Civitai motion LoRA)_ |
| `ENABLE_JUPYTER` | `true` |
| `JUPYTER_TOKEN` | _(set a password if you'll expose 8888)_ |
| `COMFY_EXTRA_ARGS` | _(optional, e.g. `--reserve-vram 2`)_ |
| `HF_TOKEN` | _(optional — not needed for the default preset)_ |

> **Want LTX only?** Set `INSTALL_ANIMATEDIFF=false`. **AnimateDiff only?** Set
> `MODEL_PRESET=none` (skips the ~68 GB LTX set; the ~8 GB AnimateDiff set still installs).
>
> For the cheap 24 GB path instead: set `MODEL_PRESET=ltx097`, attach a ~40 GB volume (or
> ~55 GB with the AnimateDiff add-on), and a 4090 is plenty.

---

## C. Deploy the Pod

**Pods → Deploy → GPU Pod**

1. Under **Network Volume**, select `ltx-models` (this locks you to its data center).
2. Pick a GPU: **L40S 48 GB** or **A6000 48 GB** for `ltx23` (A100/H100 80 GB for headroom).
3. Select your `comfyui-ltx23` template.
4. Deploy. Watch **Logs** — first boot downloads models (10–40 min). Look for
   `Starting ComfyUI on :8188`.
5. **Connect → HTTP Service 8188** → ComfyUI opens at
   `https://<POD_ID>-8188.proxy.runpod.net`.

## Costs (rough, on-demand; verify current RunPod pricing)

- Storage: Network Volume ≈ **$0.07/GB/mo** → 150 GB ≈ **$10.50/mo** (billed while it exists,
  even when no pod runs).
- Compute (only while a pod runs): RTX 4090 ≈ $0.34–0.69/hr · L40S ≈ $0.86/hr ·
  A100 80 GB ≈ $1.19–1.89/hr · H100 ≈ $2–3/hr.

**Stop the pod when idle** to stop compute billing; the volume (and your downloaded models)
persists so the next boot is fast.

## Updating the image

When you push a new image tag, edit the template's **Container Image** to the new tag and
redeploy. Models on the volume are untouched. Use **pinned tags** (`:v1.0.1`), not `:latest`,
to avoid RunPod caching an old layer.
