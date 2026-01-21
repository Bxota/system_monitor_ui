#!/usr/bin/env bash
set -euo pipefail

ASSET_NAME="libsysmon-macos.tar.gz"
OUT_DIR="${OUT_DIR:-vendor/sysmon}"
ARCHS="${ARCHS:-}"
FORCE_BUILD_FROM_SOURCE="${FORCE_BUILD_FROM_SOURCE:-0}"
SUDO_CMD="${SUDO_CMD:-}"

resolve_core_repo() {
  if [ -n "${CORE_REPO:-}" ]; then
    return
  fi

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

  if [ -z "${CORE_REPO:-}" ]; then
    echo "CORE_REPO is not set (example: CORE_REPO=Bxota/system_monitor_core)" >&2
    exit 1
  fi
}

default_archs_if_needed() {
  if [ -n "${ARCHS:-}" ]; then
    return
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    ARCHS="arm64 x86_64"
  fi
}

download_release() {
  local tmp_dir="$1"

  url="https://github.com/${CORE_REPO}/releases/download/latest/${ASSET_NAME}"
  echo "Downloading ${url}"

  curl_args=(-fL -o "${tmp_dir}/${ASSET_NAME}")
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi
  curl "${curl_args[@]}" "${url}"

  ${SUDO_CMD} mkdir -p "${OUT_DIR}"
  ${SUDO_CMD} rm -rf "${OUT_DIR}/sysmon"
  ${SUDO_CMD} tar -xzf "${tmp_dir}/${ASSET_NAME}" -C "${OUT_DIR}"
}

lib_has_required_archs() {
  local lib_path="$1"

  if [ -z "${ARCHS:-}" ] || ! command -v lipo >/dev/null 2>&1; then
    return 0
  fi

  if [ ! -f "${lib_path}" ]; then
    return 1
  fi

  local present_archs
  present_archs="$(lipo -archs "${lib_path}")"

  for arch in ${ARCHS}; do
    if ! printf "%s\n" "${present_archs}" | tr ' ' '\n' | grep -q "^${arch}$"; then
      return 1
    fi
  done

  return 0
}

build_from_source() {
  local tmp_dir="$1"
  local src_dir="${tmp_dir}/system_monitor_core"
  local build_dir="${tmp_dir}/build"

  if ! command -v cmake >/dev/null 2>&1; then
    echo "cmake is required to build libsysmon from source" >&2
    exit 1
  fi

  echo "Building libsysmon from source (${CORE_REPO})"
  git clone --depth 1 "https://github.com/${CORE_REPO}.git" "${src_dir}"

  local cmake_archs=""
  if [ -n "${ARCHS:-}" ]; then
    cmake_archs="$(printf "%s" "${ARCHS}" | tr ' ' ';')"
  fi

  local cmake_args=(
    -DSYSMON_BUILD_CLI=OFF
    -DCMAKE_BUILD_TYPE=Release
  )
  if [ -n "${cmake_archs}" ]; then
    cmake_args+=(-DCMAKE_OSX_ARCHITECTURES="${cmake_archs}")
  fi

  cmake -S "${src_dir}" -B "${build_dir}" "${cmake_args[@]}"

  cmake --build "${build_dir}" --config Release -j

  ${SUDO_CMD} mkdir -p "${OUT_DIR}/sysmon"
  ${SUDO_CMD} rm -rf "${OUT_DIR}/sysmon/include"
  ${SUDO_CMD} cp -R "${src_dir}/include" "${OUT_DIR}/sysmon/include"

  if [ -f "${build_dir}/libsysmon.a" ]; then
    ${SUDO_CMD} cp "${build_dir}/libsysmon.a" "${OUT_DIR}/sysmon/libsysmon.a"
  elif [ -f "${build_dir}/Release/libsysmon.a" ]; then
    ${SUDO_CMD} cp "${build_dir}/Release/libsysmon.a" "${OUT_DIR}/sysmon/libsysmon.a"
  else
    echo "Could not find libsysmon.a in build output" >&2
    exit 1
  fi
}

resolve_core_repo
default_archs_if_needed

if [ -z "${SUDO_CMD}" ]; then
  target_parent="${OUT_DIR%/*}"
  if [ ! -d "${target_parent}" ]; then
    target_parent="."
  fi

  if { [ -d "${OUT_DIR}" ] && [ ! -w "${OUT_DIR}" ]; } || [ ! -w "${target_parent}" ]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO_CMD="sudo"
    else
      echo "No write access to ${OUT_DIR}. Run with sudo or set SUDO_CMD to a privilege helper." >&2
      exit 1
    fi
  fi
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [ "${FORCE_BUILD_FROM_SOURCE}" = "1" ]; then
  build_from_source "${tmp_dir}"
else
  download_release "${tmp_dir}"
fi

if ! lib_has_required_archs "${OUT_DIR}/sysmon/libsysmon.a"; then
  echo "libsysmon.a missing required architectures (${ARCHS}); rebuilding from source" >&2
  build_from_source "${tmp_dir}"
fi

echo "Done. Extracted to ${OUT_DIR}/sysmon"
