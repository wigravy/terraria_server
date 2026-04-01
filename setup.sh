#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Create it from ${SCRIPT_DIR}/.env.example"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

SERVER_DATA="${SERVER_DATA:-server_data}"
if [[ "${SERVER_DATA}" != /* ]]; then
  SERVER_DATA="${SCRIPT_DIR}/${SERVER_DATA}"
fi
TML_DIR="${SERVER_DATA}/tmodloader"
MODS_DIR="${SERVER_DATA}/Mods"
WORLDS_DIR="${SERVER_DATA}/Worlds"
TMP_ZIP="/tmp/tmodloader_release.zip"

resolve_tml_root() {
  local base_dir="$1"
  local candidate

  for candidate in \
    "${base_dir}" \
    "${base_dir}/tModLoader" \
    "${base_dir}/steamapps/common/tModLoader"
  do
    if [[ -f "${candidate}/start-tModLoaderServer.sh" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

get_release_url() {
  local api_url
  local response

  if [[ -n "${TMODLOADER_RELEASE_TAG:-}" ]]; then
    api_url="https://api.github.com/repos/tModLoader/tModLoader/releases/tags/${TMODLOADER_RELEASE_TAG}"
  else
    api_url="https://api.github.com/repos/tModLoader/tModLoader/releases/latest"
  fi

  RELEASE_METADATA="$(curl -fsSL "${api_url}")"
  TML_RELEASE_TAG="$(printf '%s\n' "${RELEASE_METADATA}" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n 1)"
  RELEASE_URL="$(printf '%s\n' "${RELEASE_METADATA}" \
    | sed -n 's/.*"browser_download_url": "\([^"]*\/tModLoader\.zip\)".*/\1/p' \
    | head -n 1)"
}

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y curl unzip lib32gcc-s1 ca-certificates tmux

mkdir -p "${SERVER_DATA}" "${TML_DIR}" "${MODS_DIR}" "${WORLDS_DIR}"

if ! get_release_url; then
  echo "Failed to resolve the tModLoader release download URL from GitHub."
  exit 1
fi

if [[ -z "${RELEASE_URL}" ]]; then
  echo "Could not find tModLoader.zip in the selected GitHub release."
  exit 1
fi

echo "Downloading tModLoader release ${TML_RELEASE_TAG:-unknown} from GitHub"
curl -fL "${RELEASE_URL}" -o "${TMP_ZIP}"

find "${TML_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
unzip -oq "${TMP_ZIP}" -d "${TML_DIR}"
rm -f "${TMP_ZIP}"

if ! TML_ROOT="$(resolve_tml_root "${TML_DIR}")"; then
  echo "tModLoader server script was not found under ${TML_DIR}"
  echo "Checked:"
  echo "  ${TML_DIR}"
  echo "  ${TML_DIR}/tModLoader"
  echo "  ${TML_DIR}/steamapps/common/tModLoader"
  exit 1
fi

chmod +x "${TML_ROOT}"/*.sh || true

ENABLED_FILE="${MODS_DIR}/enabled.json"

if [[ -f "${ENABLED_FILE}" ]]; then
  echo "Using existing ${ENABLED_FILE}"
else
  declare -a ENABLED_MODS=()

  while IFS= read -r mod_file; do
    mod_name="$(basename "${mod_file}" .tmod)"
    if [[ -n "${mod_name}" ]]; then
      ENABLED_MODS+=("${mod_name}")
    fi
  done < <(find "${MODS_DIR}" -maxdepth 1 -type f -name '*.tmod' | sort)

  if (( ${#ENABLED_MODS[@]} > 0 )); then
    {
      echo "["
      for i in "${!ENABLED_MODS[@]}"; do
        separator=","
        if [[ "${i}" -eq $((${#ENABLED_MODS[@]} - 1)) ]]; then
          separator=""
        fi
        printf '  "%s"%s\n' "${ENABLED_MODS[$i]}" "${separator}"
      done
      echo "]"
    } > "${ENABLED_FILE}"

    echo "Created ${ENABLED_FILE} from local .tmod files."
  else
    echo "No .tmod files found in ${MODS_DIR}; enabled.json was not created."
  fi
fi

echo
echo "Server data directory: ${SERVER_DATA}"
echo "GitHub release tag: ${TML_RELEASE_TAG:-unknown}"
echo "tModLoader install directory: ${TML_ROOT}"
echo "Mods directory: ${MODS_DIR}"
echo "Worlds directory: ${WORLDS_DIR}"
echo
echo "Setup complete."
echo "Place your mods and install.txt in ${MODS_DIR} if needed, then run ./start-server.sh"
