#!/bin/bash
set -e

echo "=== Motor Town Dedicated Server (Proton GE) ==="

# Motor Town defaults (override via -e or docker-compose)
: ${STEAMAPPID:=2223650}
: ${STEAMAPPVALIDATE:=0}
: ${SERVER_HOSTNAME:="motortown private server"}
: ${SERVER_MESSAGE:="Welcome!\nHave fun!"}
: ${SERVER_PASSWORD:=""}
: ${MAX_PLAYERS:=10}
: ${MAX_PLAYER_VEHICLES:=5}
: ${ALLOW_COMPANY_VEHCILES:=false}
: ${ALLOW_COMPANY_AI:=true}
: ${MAX_HOUSING_RENTAL_PLOTS:=1}
: ${MAX_HOUSING_RENTAL_DAYS:=7}
: ${HOUSING_RENTAL_PRICE_RATIO:=0.1}
: ${ALLOW_MODDED_VEHICLES:=false}
: ${NPC_VEHICLE_DENSITY:=1.0}
: ${NPC_POLICE_DENSITY:=1.0}
: ${ENABLE_WEB_API:=false}
: ${WEB_API_PASSWORD:="p4ssw0rd"}
: ${WEB_API_PORT:=8080}
: ${MT_CFG_URL:=""}

# === REQUIRED: Steam account credentials ===
if [[ -z "${STEAM_USERNAME}" || -z "${STEAM_PASSWORD}" ]]; then
    echo "ERROR: STEAM_USERNAME and STEAM_PASSWORD environment variables are required."
    echo "       Your Steam account must own 'Motor Town: Behind The Wheel'."
    exit 1
fi

# Update game (beta test2)
echo "--- Updating Motor Town Dedicated Server (beta test2) ---"
VALIDATE_FLAG=$([ "${STEAMAPPVALIDATE}" = "1" ] && echo "validate" || echo "")
${STEAMCMD_DIR}/steamcmd.sh \
    +force_install_dir "${STEAM_APP_DIR}" \
    +login "${STEAM_USERNAME}" "${STEAM_PASSWORD}" "${GUARD_CODE:-}" \
    +app_update ${STEAMAPPID} -beta beta -betapassword motortowndedi ${VALIDATE_FLAG} \
    +quit

# === CORRECT CONFIG LOCATION (root of server directory) ===
echo "--- Generating DedicatedServerConfig.json in correct root location ---"
mkdir -p "${STEAM_APP_DIR}"

cp "${STEAM_HOME}/DedicatedServerConfig_Sample.json" "${STEAM_APP_DIR}/DedicatedServerConfig.json"

sed -i \
    -e "s/{{SERVER_HOSTNAME}}/${SERVER_HOSTNAME}/g" \
    -e "s/{{SERVER_MESSAGE}}/${SERVER_MESSAGE}/g" \
    -e "s/{{SERVER_PASSWORD}}/${SERVER_PASSWORD}/g" \
    -e "s/{{MAX_PLAYERS}}/${MAX_PLAYERS}/g" \
    -e "s/{{MAX_PLAYER_VEHICLES}}/${MAX_PLAYER_VEHICLES}/g" \
    -e "s/{{ALLOW_COMPANY_VEHCILES}}/${ALLOW_COMPANY_VEHCILES}/g" \
    -e "s/{{ALLOW_COMPANY_AI}}/${ALLOW_COMPANY_AI}/g" \
    -e "s/{{MAX_HOUSING_RENTAL_PLOTS}}/${MAX_HOUSING_RENTAL_PLOTS}/g" \
    -e "s/{{MAX_HOUSING_RENTAL_DAYS}}/${MAX_HOUSING_RENTAL_DAYS}/g" \
    -e "s/{{HOUSING_RENTAL_PRICE_RATIO}}/${HOUSING_RENTAL_PRICE_RATIO}/g" \
    -e "s/{{ALLOW_MODDED_VEHICLES}}/${ALLOW_MODDED_VEHICLES}/g" \
    -e "s/{{NPC_VEHICLE_DENSITY}}/${NPC_VEHICLE_DENSITY}/g" \
    -e "s/{{NPC_POLICE_DENSITY}}/${NPC_POLICE_DENSITY}/g" \
    -e "s/{{ENABLE_WEB_API}}/${ENABLE_WEB_API}/g" \
    -e "s/{{WEB_API_PASSWORD}}/${WEB_API_PASSWORD}/g" \
    -e "s/{{WEB_API_PORT}}/${WEB_API_PORT}/g" \
    "${STEAM_APP_DIR}/DedicatedServerConfig.json"

echo "✓ Config written to correct location: ${STEAM_APP_DIR}/DedicatedServerConfig.json"

# Install Steam Linux Runtime and copy compatibility DLLs
echo "--- Installing Steam Linux Runtime and copying compatibility DLLs ---"
${STEAMCMD_DIR}/steamcmd.sh +force_install_dir "${STEAM_APP_DIR}" +login anonymous +app_update 1007 validate +quit

mkdir -p "${STEAM_APP_DIR}/MotorTown/Binaries/Win64"
for dll in steamclient.dll steamclient64.dll tier0_s.dll tier0_s64.dll vstdlib_s.dll vstdlib_s64.dll; do
    src_so="${STEAMCMD_DIR}/linux32/${dll%.dll}.so"
    if [ -f "$src_so" ]; then
        cp "$src_so" "${STEAM_APP_DIR}/MotorTown/Binaries/Win64/${dll}"
        echo "Copied ${dll}"
    else
        echo "Warning: Could not find ${dll} source"
    fi
done

# Custom config bundle support
if [[ -n "${MT_CFG_URL}" ]]; then
    echo "Downloading custom config pack from ${MT_CFG_URL}"
    TEMP_DIR=$(mktemp -d)
    TEMP_FILE="${TEMP_DIR}/$(basename ${MT_CFG_URL})"
    wget -qO "${TEMP_FILE}" "${MT_CFG_URL}"
    case "${TEMP_FILE}" in
        *.zip) unzip -q "${TEMP_FILE}" -d "${STEAM_APP_DIR}" ;;
        *.tar.gz|*.tgz) tar xvzf "${TEMP_FILE}" -C "${STEAM_APP_DIR}" ;;
        *.tar) tar xvf "${TEMP_FILE}" -C "${STEAM_APP_DIR}" ;;
        *) echo "Unsupported archive type"; rm -rf "${TEMP_DIR}"; exit 1 ;;
    esac
    rm -rf "${TEMP_DIR}"
fi

# Pre-hook
source "${STEAM_HOME}/pre.sh"

# Proton environment
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAMCMD_DIR}"
export STEAM_COMPAT_DATA_PATH="${STEAMCMD_DIR}/compatdata/${STEAMAPPID}"
mkdir -p "${STEAM_COMPAT_DATA_PATH}"
export SteamAppId=${STEAMAPPID}
export LD_LIBRARY_PATH="${STEAM_APP_DIR}/linux64:${LD_LIBRARY_PATH}"

# Live logging
echo "--- Starting real-time ServerLog forwarding to Docker stdout ---"
mkdir -p "${STEAM_APP_DIR}/MotorTown/Saved/ServerLog"
(
    echo "Waiting for Motor Town ServerLog files to appear..."
    while true; do
        LOGFILE=$(find "${STEAM_APP_DIR}/MotorTown/Saved/ServerLog" -name "*.log" -type f 2>/dev/null | head -n 1)
        if [ -n "$LOGFILE" ]; then
            echo "=== Now following game log: $LOGFILE ==="
            tail -f "$LOGFILE"
            break
        fi
        sleep 2
    done
) &

echo "--- Launching Motor Town Dedicated Server ---"
cd "${STEAM_APP_DIR}"

exec "${PROTON_EXECUTABLE_PATH}" waitforexitandrun \
    "${STEAM_APP_DIR}/MotorTown/Binaries/Win64/MotorTownServer-Win64-Shipping.exe" \
    Jeju_World?listen -server -log -useperfthreads
    
# Post-hook
source "${STEAM_HOME}/post.sh"
