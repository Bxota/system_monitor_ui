#!/usr/bin/env bash
set -euo pipefail

ASSET_NAME="libsysmon-macos.tar.gz"
OUT_DIR="${OUT_DIR:-vendor/sysmon}"

if [ -z "${CORE_REPO:-}" ]; then
  CORE_REPO=""
  if git_remote="$(git config --get remote.origin.url 2>/dev/null)"; then
    git_remote="${git_remote%.git}"
    case "$git_remote" in
      git@github.com:*) core_repo="${git_remote#git@github.com:}" ;;
      https://github.com/*) core_repo="${git_remote#https://github.com/}" ;;
      *) core_repo="" ;;
    esac
    if [ -n "${core_repo:-}" ]; then
      owner="${core_repo%%/*}"
      repo="${core_repo##*/}"
      if [ "$repo" = "system_monitor_ui" ]; then
        repo="system_monitor_core"
      fi
      CORE_REPO="${owner}/${repo}"
    fi
  fi
fi

if [ -z "${CORE_REPO:-}" ]; then
  echo "CORE_REPO is not set (example: CORE_REPO=Bxota/system_monitor_core)" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

url="https://github.com/${CORE_REPO}/releases/download/latest/${ASSET_NAME}"
echo "Downloading ${url}"

curl_args=(-fL -o "${tmp_dir}/${ASSET_NAME}")
if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
fi
curl "${curl_args[@]}" "${url}"

mkdir -p "${OUT_DIR}"
rm -rf "${OUT_DIR}/sysmon"
tar -xzf "${tmp_dir}/${ASSET_NAME}" -C "${OUT_DIR}"

echo "Done. Extracted to ${OUT_DIR}/sysmon"
