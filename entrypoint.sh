#!/bin/bash

# Exit immediately on error
set -e

echo "--- Ubuntu-based Proton Server ---"
echo "Proton Version: ${PROTON_VERSION}"

# Update / install the game via SteamCMD when STEAM_APP_ID is provided.
# Anonymous login is used for most dedicated servers; use credentials if required.
if [ -n "${STEAM_APP_ID}" ]; then
    echo "--- Checking for updates (App ID: ${STEAM_APP_ID}) ---"
    ${STEAMCMD_DIR}/steamcmd.sh \
        +force_install_dir "${STEAM_APP_DIR}" \
        +login "${STEAMCMD_USER}" "${STEAMCMD_PW} \
        +@sSteamCmdForcePlatformType windows \
        +app_update "${STEAM_APP_ID}" validate \
        +quit
else
    echo "!!! Warning: STEAM_APP_ID not set. Skipping Steam update. !!!"
    exit 1
fi

# Ensure the game executable path is provided (relative to STEAM_APP_DIR)
if [ -z "${GAME_EXECUTABLE}" ]; then
    echo "ERROR: GAME_EXECUTABLE environment variable is missing."
    echo "Example: Binaries/Win64/Server.exe"
    exit 1
fi

# Optional: start Xvfb for Windows binaries that require an X display.
# Uncomment these lines if the game crashes without a display.
# echo "--- Starting Virtual Display (Xvfb) ---"
# Xvfb :99 -screen 0 800x600x16 &
# export DISPLAY=:99

echo "--- Launching ${STEAM_APP_DIR}/${GAME_EXECUTABLE} ---"

# Verify the game executable exists before launching
if [ ! -f "${STEAM_APP_DIR}/${GAME_EXECUTABLE}" ]; then
    echo "ERROR: Game executable not found at ${STEAM_APP_DIR}/${GAME_EXECUTABLE}"
    exit 1
fi

# Proton compatibility environment (paths used by Proton)
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAMCMD_DIR}"
export STEAM_COMPAT_DATA_PATH="${STEAMCMD_DIR}/compatdata/${STEAM_APP_ID}"

# Ensure compatibility data directory exists
mkdir -p "${STEAM_COMPAT_DATA_PATH}"

# Game specific settings
export SteamAppId=${STEAM_APP_ID}
export LD_LIBRARY_PATH="${STEAM_APP_DIR}/linux64:${LD_LIBRARY_PATH}"

# Use exec with the program and its arguments split so the shell is replaced correctly.
exec "${PROTON_EXECUTABLE_PATH}" waitforexitandrun "${STEAM_APP_DIR}/${GAME_EXECUTABLE}" ${GAME_ARGS}
