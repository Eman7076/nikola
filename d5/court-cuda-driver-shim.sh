# D5.5 — Arch / NixOS NVIDIA driver path for nix-built CUDA libs.
# Source from shellHook, or run via court-llama-env.
#
# Fact (Court, measured on the rig): libggml-cuda.so needs the *host*
# libcuda.so.1, not the nixpkgs CUDA stub. On NixOS, /run/opengl-driver/lib
# is the right place. On Arch there is no such path; a directory of
# *driver-only* symlinks from /usr/lib, prepended to LD_LIBRARY_PATH, makes
# llama_supports_gpu_offload() True. Do NOT add all of /usr/lib (Court
# measured: nix python then loads Arch glibc and dies on GLIBC_PRIVATE).
#
# Patterns below = Court report. Untested on Nikola's VM (no NVIDIA).
#
# D5.5.1 (Court 2026-09-24): on Arch /usr/lib64 often resolves to the same
# directory as /usr/lib, so iterating both double-counted ln attempts (24
# printed, 12 files on disk). Deduplicate search roots by realpath; report
# the final link count in the shim directory.

court_cuda_driver_shim_setup() {
  if [ -d /run/opengl-driver/lib ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
      *:/run/opengl-driver/lib:*) ;;
      *) export LD_LIBRARY_PATH="/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
    echo "court-cuda-shim: NixOS path /run/opengl-driver/lib on LD_LIBRARY_PATH"
    return 0
  fi

  _court_shim_root="${XDG_RUNTIME_DIR:-/tmp}/court-nvidia-driver-shim"
  mkdir -p "$_court_shim_root" || {
    echo "court-cuda-shim: WARNING: cannot create $_court_shim_root" >&2
    return 1
  }
  # Drop prior links so a stale set cannot linger across driver upgrades.
  find "$_court_shim_root" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null || true

  if [ ! -d /usr/lib ] && [ ! -d /usr/lib64 ]; then
    echo "court-cuda-shim: WARNING: neither /run/opengl-driver/lib nor /usr/lib{,64} present; GPU offload may stay False" >&2
    return 1
  fi

  # Build a unique list of search roots (Arch: /usr/lib64 -> /usr/lib).
  _court_dirs=""
  for _court_cand in /usr/lib /usr/lib64; do
    [ -d "$_court_cand" ] || continue
    _court_real=$(realpath "$_court_cand" 2>/dev/null || echo "$_court_cand")
    _court_seen=0
    for _court_existing in $_court_dirs; do
      if [ "$_court_existing" = "$_court_real" ]; then
        _court_seen=1
        break
      fi
    done
    if [ "$_court_seen" -eq 0 ]; then
      _court_dirs="${_court_dirs} ${_court_real}"
    fi
  done
  _court_dirs=$(echo $_court_dirs | sed 's/^ *//')

  if [ -z "$_court_dirs" ]; then
    echo "court-cuda-shim: WARNING: no usable /usr/lib{,64} after realpath; GPU offload may stay False" >&2
    return 1
  fi

  # Court-measured set only — never glob the whole /usr/lib tree into the shim.
  for _court_pat in \
    'libcuda.so*' \
    'libnvidia-ptxjitcompiler.so*' \
    'libnvidia-ml.so*' \
    'libnvidia-nvvm.so*'
  do
    for _court_dir in $_court_dirs; do
      for _court_f in "$_court_dir"/$_court_pat; do
        [ -e "$_court_f" ] || continue
        ln -sfn "$_court_f" "$_court_shim_root/$(basename "$_court_f")"
      done
    done
  done

  # Count what actually sits in the shim dir (truth), not ln attempts.
  _court_linked=$(find "$_court_shim_root" -maxdepth 1 -type l | wc -l | tr -d ' ')

  if [ "$_court_linked" -eq 0 ]; then
    echo "court-cuda-shim: WARNING: no NVIDIA driver libs matched under /usr/lib{,64}; llama_supports_gpu_offload() may stay False" >&2
    return 1
  fi

  export LD_LIBRARY_PATH="$_court_shim_root${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  echo "court-cuda-shim: Arch driver-only shim ($_court_linked links) at $_court_shim_root (not all of /usr/lib)"
  return 0
}
