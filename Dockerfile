FROM ubuntu:24.04

LABEL maintainer="xiahualiu + community (Motor Town Proton port)"
LABEL description="Motor Town: Behind The Wheel Dedicated Server (Proton GE)"

# Non-interactive apt operations in Docker builds
ENV DEBIAN_FRONTEND=noninteractive

# Build-time arguments (can be overridden with --build-arg)
ARG STEAM_USER="steam"
ARG STEAM_HOME="/home/steam"
ARG STEAM_USER_UID=1000
ARG STEAM_USER_GID=1000
ARG STEAMCMD_DIR="${STEAM_HOME}/steamcmd"
ARG STEAM_APP_DIR="${STEAM_HOME}/server"
ARG PROTON_VERSION="GE-Proton10-28"
# Proton lives inside a Steam-like compatibilitytools.d structure so Proton's
# internal scripts can resolve sibling paths correctly (mirrors real Steam layout).
ARG STEAM_CLIENT_DIR="${STEAM_HOME}/.steam/steam"
ARG PROTON_DIR="${STEAM_CLIENT_DIR}/compatibilitytools.d/GE-Proton10-28"

# Runtime environment variables derived from build args
ENV STEAM_USER=${STEAM_USER}
ENV STEAM_HOME=${STEAM_HOME}
ENV STEAMCMD_DIR=${STEAMCMD_DIR}
ENV STEAM_APP_DIR=${STEAM_APP_DIR}
ENV PROTON_VERSION=${PROTON_VERSION}
ENV PROTON_DIR=${PROTON_DIR}
ENV PROTON_EXECUTABLE_PATH="${PROTON_DIR}/proton"

# Point Proton at the Steam-like directory so it resolves its own runtime paths.
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_HOME}/.steam/steam"

# Disable ULWGL game-specific compatibility patches (they can break server mode).
ENV ULWGL_ID=0

# URL for downloading the chosen GE-Proton release
ENV PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz"

# Set locale environment variables
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install runtime and SteamCMD dependencies, including 32-bit libs required by Steam
RUN dpkg --add-architecture i386 \
    && apt-get update && apt-get install -y \
        wget \
        curl \
        tar \
        python3 \
        adduser \
        perl \
        xvfb \
        lib32gcc-s1 \
        lib32stdc++6 \
        libgl1:i386 \
        libgl1-mesa-dri:i386 \
        ca-certificates \
        locales \
        dbus \
    # Generate locale to avoid encoding issues in logs
    && locale-gen en_US.UTF-8 \
    # Cleanup apt lists to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Remove default ubuntu user to avoid conflicts
RUN deluser --remove-home ubuntu

# Create the unprivileged steam user and group with specified UID/GID
RUN groupadd -g ${STEAM_USER_GID} ${STEAM_USER} \
    && useradd -m -u ${STEAM_USER_UID} -g ${STEAM_USER_GID} -s /bin/bash ${STEAM_USER}

# Ensure a stable machine id is present (some Proton/Steam behavior requires it)
RUN rm -f /etc/machine-id \
    && dbus-uuidgen --ensure=/etc/machine-id

# Switch to the unprivileged steam user for downloads and runtime file setup
USER ${STEAM_USER}
WORKDIR ${STEAM_HOME}

# Download and extract SteamCMD into the configured directory, then run once to bootstrap
RUN mkdir -p ${STEAMCMD_DIR} \
    && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C ${STEAMCMD_DIR} \
    && ${STEAMCMD_DIR}/steamcmd.sh +quit

# Create Steam SDK symlinks used by many servers/games (64-bit and 32-bit)
RUN mkdir -p ${STEAM_HOME}/.steam/sdk64 \
    && mkdir -p ${STEAM_HOME}/.steam/sdk32 \
    && ln -sf ${STEAMCMD_DIR}/linux64/steamclient.so ${STEAM_HOME}/.steam/sdk64/steamclient.so \
    && ln -sf ${STEAMCMD_DIR}/linux32/steamclient.so ${STEAM_HOME}/.steam/sdk32/steamclient.so \
    && ln -sf ${STEAMCMD_DIR}/linux64/steamclient.so ${STEAM_HOME}/.steam/sdk64/steamservice.so \
    && ln -sf ${STEAMCMD_DIR}/linux32/steamclient.so ${STEAM_HOME}/.steam/sdk32/steamservice.so \
    && ln -sf ${STEAMCMD_DIR}/linux64 ${STEAM_HOME}/.steam/bin64 \
    && ln -sf ${STEAMCMD_DIR}/linux32 ${STEAM_HOME}/.steam/bin32

# Download and unpack GE-Proton into compatibilitytools.d/ (mirrors real Steam layout)
RUN mkdir -p ${PROTON_DIR} \
    && wget -qO- ${PROTON_URL} | tar -xz --strip-components=1 -C ${PROTON_DIR}

# Ensure the Proton wrapper is executable
RUN chmod +x ${PROTON_EXECUTABLE_PATH}

# Create directories for game server files and Proton fixes configuration
RUN mkdir -p ${STEAM_APP_DIR} \
    && mkdir -p ${STEAM_HOME}/.config/protonfixes

# Copy the entrypoint script into the image and make it executable
# Copy Motor Town specific files (config template + hooks)
COPY --chown=${STEAM_USER}:${STEAM_USER} etc/DedicatedServerConfig_Sample.json ${STEAM_HOME}/DedicatedServerConfig_Sample.json
COPY --chown=${STEAM_USER}:${STEAM_USER} etc/pre.sh ${STEAM_HOME}/pre.sh
COPY --chown=${STEAM_USER}:${STEAM_USER} etc/post.sh ${STEAM_HOME}/post.sh
COPY --chown=${STEAM_USER}:${STEAM_USER} entrypoint.sh ${STEAM_HOME}/entrypoint.sh

RUN chmod +x ${STEAM_HOME}/entrypoint.sh ${STEAM_HOME}/pre.sh ${STEAM_HOME}/post.sh

# Run the entrypoint via bash to allow shell features in the script
ENTRYPOINT ["/home/steam/entrypoint.sh"]
