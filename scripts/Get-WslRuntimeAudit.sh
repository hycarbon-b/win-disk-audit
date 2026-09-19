#!/usr/bin/env bash
set -u

echo "audit_version=1"
echo "generated_at=$(date --iso-8601=seconds 2>/dev/null || date)"
echo "distribution=${WSL_DISTRO_NAME:-unknown}"
echo "user=$(id -un)"

echo "--- filesystem ---"
df -B1 -T / 2>/dev/null || true

echo "--- memory_and_swap ---"
free -b 2>/dev/null || true
swapon --show --bytes 2>/dev/null || true

echo "--- home_top_level_bytes ---"
home_dir="${HOME:-/home/$(id -un)}"
timeout 45s du -x -B1 -d1 "$home_dir" 2>/dev/null | sort -nr | head -30 || true

echo "--- common_cache_bytes ---"
cache_paths=("$home_dir/.cache" "$home_dir/.npm" "$home_dir/.local" "$home_dir/.pnpm-store" "$home_dir/.cargo")
existing_paths=()
for path in "${cache_paths[@]}"; do
  if [[ -e "$path" ]]; then existing_paths+=("$path"); fi
done
if (( ${#existing_paths[@]} > 0 )); then
  timeout 45s du -x -B1 -d2 "${existing_paths[@]}" 2>/dev/null | sort -nr | head -40 || true
fi

echo "--- docker_system_df ---"
if command -v docker >/dev/null 2>&1; then
  docker system df 2>&1 || true
else
  echo "docker_not_found=true"
fi

echo "--- notes ---"
echo "read_only=true"
echo "vhdx_compaction_required_after_internal_cleanup=true"
