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

SERVER_ROOT="${INSTALL_DIR}"
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
