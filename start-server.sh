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

INSTALL_DIR="${INSTALL_DIR:-${SCRIPT_DIR}/tmodloader}"
DATA_DIR="${DATA_DIR:-${SCRIPT_DIR}/server_data}"

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

if ! SERVER_ROOT="$(resolve_tml_root "${INSTALL_DIR}")"; then
  echo "Missing tModLoader server install under ${INSTALL_DIR}"
  echo "Checked:"
  echo "  ${INSTALL_DIR}"
  echo "  ${INSTALL_DIR}/tModLoader"
  echo "  ${INSTALL_DIR}/steamapps/common/tModLoader"
  echo "Run ./setup.sh first."
  exit 1
fi

SERVER_SCRIPT="${SERVER_ROOT}/start-tModLoaderServer.sh"
WORLD_DIR="${DATA_DIR}/Worlds"
MODS_DIR="${DATA_DIR}/Mods"
CONFIG_FILE="${SCRIPT_DIR}/serverconfig.txt"

mkdir -p "${DATA_DIR}" "${WORLD_DIR}" "${MODS_DIR}"

cat > "${CONFIG_FILE}" <<EOF
world=${WORLD_DIR}/${WORLD_NAME}.wld
autocreate=${WORLD_SIZE}
seed=${WORLD_SEED}
worldname=${WORLD_NAME}
difficulty=${WORLD_DIFFICULTY}
maxplayers=${MAX_PLAYERS}
port=${PORT}
password=${PASSWORD}
motd=${MOTD}
secure=1
upnp=0
npcstream=60
priority=1
banlist=banlist.txt
language=en-US
modpath=${MODS_DIR}
EOF

if [[ ! -x "${SERVER_SCRIPT}" ]]; then
  echo "Missing or non-executable ${SERVER_SCRIPT}"
  echo "Run ./setup.sh first."
  exit 1
fi

chmod +x "${SERVER_SCRIPT}"

echo "Starting ${SERVER_NAME} on port ${PORT}"
echo "World: ${WORLD_NAME}"

exec "${SERVER_SCRIPT}" -tmlsavedirectory "${DATA_DIR}" -modpath "${MODS_DIR}" -config "${CONFIG_FILE}"
