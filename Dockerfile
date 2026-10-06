# =============================================================================
# sneaky/vdr:2.6 - Headless VDR recording server
#
# Replaces:  sneaky/vdr:latest (Ubuntu 18.04, VDR 2.4.0, ~2020, manually extended)
# Base:      Debian 13 "trixie" -> VDR 2.6.9 from Debian packages
# Reference: technik-notfallbuch: server/vdr.md + Issue #2 (migration plan)
#
# Contract with existing docker-compose.yml (kept 1:1):
#   devices : /dev/dvb:/dev/dvb   (Digital Devices Octopus [dd01:0003], PCI-Passthrough)
#   volumes : /srv/vdr/video  <- /mnt/bighdd/mediareceiver/vdr  (recordings)
#             /etc/vdr        <- /mnt/container-data/vdr/etc     (plugin configuration)
#             /var/lib/vdr    <- /mnt/container-data/vdr/var    (setup/channels/svdrphosts)
#   ports   : 2004 3000 6419 8001 8002 8008 34890
#
# Plugin set (intentionally minimal, Issue #2):
#   Debian package: epgsearch, streamdev (Server)
#   Source build:   restfulapi (8002, REST-API)
#                  ddci2 (CI adapter for Octopus)
#                  dummydevice (headless)
#                  vnsiserver (Kodi/VNSI)
#                  svdrposd + svdrpservice (legacy smartphone app via SVDRP 6419)
#                  live (Web UI 8008)
# Omitted: satip, eepg, xmltv2vdr, robotv, iptv, wirbelscan, femon, vdradmin-am
# =============================================================================

FROM debian:trixie

ARG BUILD_DATE
LABEL org.opencontainers.image.title="sneaky/vdr" \
      org.opencontainers.image.description="VDR 2.6 headless recording server" \
      org.opencontainers.image.version="2.6" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      maintainer="sneaky"

ENV TZ=Europe/Berlin \
    VDRDIR=/usr/include/vdr \
    LIBDIR=/usr/lib/vdr

# -----------------------------------------------------------------------------
# Base system + VDR 2.6.9 + Debian plugins
# (Debian trixie: streamdev is split into -server/-client; we only need
#  the server. epgsearch is available as vdr-plugin-epgsearch.)
# -----------------------------------------------------------------------------
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git build-essential pkg-config tzdata \
      vdr vdr-dev \
      vdr-plugin-epgsearch \
      vdr-plugin-streamdev-server \
      vdr-plugin-live \
      libssl-dev zlib1g-dev \
      libmagick++-dev \
      libtntnet-dev libcxxtools-dev \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Directories (contract with volume mounts)
# -----------------------------------------------------------------------------
RUN mkdir -p /srv/vdr/video \
             /var/cache/vdr/epgimages \
             /usr/share/vdr/channel-logos \
             /var/lib/vdr/plugins/restfulapi \
             /etc/vdr/command-hooks \
             /etc/drafts

# Default SVDRP access (copied to /var/lib/vdr on first start,
# if no svdrphosts.conf exists there - same logic as in the old image)
RUN printf '%s\n' \
      '127.0.0.1' \
      '192.168.0.0/24' \
      '192.168.178.0/24' \
      '172.17.0.0/16' \
      > /etc/drafts/svdrphosts.conf

# -----------------------------------------------------------------------------
# Source builds: plugins without (matching) Debian package
# Standard VDR plugin build: make && make install (VDRDIR/LIBDIR from ENV above).
# If a make reports a missing header: add the corresponding -dev package above
# at apt-get and rebuild (dependencies see respective repo).
# -----------------------------------------------------------------------------

# restfulapi - REST API on port 8002, actively maintained (yaVDR, as of 10/2026)
# Fix: The plugin Makefile overwrites CXXFLAGS itself (without -fPIC, which
# vdr.pc in trixie does not provide) -> linking as shared library fails.
# The sed appends -fPIC to the "export CXXFLAGS =" line of the Makefile.
RUN git clone --depth 1 https://github.com/yavdr/vdr-plugin-restfulapi.git /src/restfulapi && \
    cd /src/restfulapi && \
    sed -i '/^export CXXFLAGS =/ s/$/ -fPIC/' Makefile && \
    make && make install && \
    cp -r web /var/lib/vdr/plugins/restfulapi/webapp && \
    rm -rf /src/restfulapi

# ddci2 - CI adapter from Digital Devices (Octopus + CI module)
RUN git clone --depth 1 https://github.com/jasmin-j/vdr-plugin-ddci2.git /src/ddci2 && \
    cd /src/ddci2 && \
    sed -i '/^CXXFLAGS/ s/$/ -fPIC/; /^export CXXFLAGS/ s/$/ -fPIC/' Makefile && \
    make && make install && rm -rf /src/ddci2

# dummydevice - headless: Dummy as primary device,
# the Octopus remains completely free for recordings
RUN git clone --depth 1 https://github.com/flensrocker/vdr-plugin-dummydevice.git /src/dummydevice && \
    cd /src/dummydevice && \
    sed -i '/^CXXFLAGS/ s/$/ -fPIC/; /^export CXXFLAGS/ s/$/ -fPIC/' Makefile && \
    make && make install && rm -rf /src/dummydevice

# vnsiserver - Streaming for Kodi clients (VNSI, port 34890)
RUN git clone --depth 1 https://github.com/vdr-projects/vdr-plugin-vnsiserver.git /src/vnsi && \
    cd /src/vnsi && \
    sed -i '/^CXXFLAGS/ s/$/ -fPIC/; /^export CXXFLAGS/ s/$/ -fPIC/' Makefile && \
    make && make install && rm -rf /src/vnsi

# svdrposd + svdrpservice - SVDRP OSD/service (basis for legacy smartphone app!)
RUN git clone --depth 1 https://github.com/vdr-projects/vdr-plugin-svdrposd.git /src/svdrposd && \
    cd /src/svdrposd && \
    sed -i '/^CXXFLAGS/ s/$/ -fPIC/; /^export CXXFLAGS/ s/$/ -fPIC/' Makefile && \
    make && make install && rm -rf /src/svdrposd
RUN git clone --depth 1 https://github.com/vdr-projects/vdr-plugin-svdrpservice.git /src/svdrpservice && \
    cd /src/svdrpservice && \
    sed -i '/^CXXFLAGS/ s/$/ -fPIC/; /^export CXXFLAGS/ s/$/ -fPIC/' Makefile && \
    make && make install && rm -rf /src/svdrpservice

# live - Web UI on 8008: NOT as source build! The rofafor Git code is
# incompatible with cxxtools 3.x (trixie) (LOG_ERROR/syslog macro conflict).
# Debian trixie provides a maintained vdr-plugin-live 3.5.0-1 via apt
# (above in the package list) - it is more recent than the Git version and builds.

# -----------------------------------------------------------------------------
# Start script (replaces /runvdr.sh of the old image)
# - Plugin list intentionally hardcoded (as before) - conf.d/ is NOT read
#   (that's exactly why restfulapi never started in the old image!)
# - --video and --config explicitly set to match the contract with mounts:
#   setup.conf/channels.conf/svdrphosts.conf are in /var/lib/vdr (var mount),
#   epgsearch data in /etc/vdr/plugins/epgsearch (etc mount)
# - --chartab=ISO-8859-1 as before (channels.conf is encoded this way; future
#   candidate for UTF-8 conversion together with channels.conf revision #36)
# -----------------------------------------------------------------------------
RUN printf '%s\n' \
      '#!/bin/sh' \
      'mkdir -p /etc/vdr/command-hooks' \
      'if [ ! -f /var/lib/vdr/svdrphosts.conf ]; then' \
      '  cp /etc/drafts/svdrphosts.conf /var/lib/vdr/svdrphosts.conf' \
      'fi' \
      'exec /usr/bin/vdr \' \
      '  --video=/srv/vdr/video \' \
      '  --config=/var/lib/vdr \' \
      '  --chartab=ISO-8859-1 \' \
      '  --port=6419 \' \
      '  -P svdrposd -P svdrpservice -P dummydevice \' \
      '  -P "epgsearch --config=/etc/vdr/plugins/epgsearch" \' \
      '  -P streamdev-server -P vnsiserver \' \
      '  -P "live -i 0.0.0.0 -p 8008" \' \
      '  -P "restfulapi --port=8002 --ip=0.0.0.0 --epgimages=/var/cache/vdr/epgimages --channellogos=/usr/share/vdr/channel-logos --webapp=/var/lib/vdr/plugins/restfulapi/webapp" \' \
      '  -P ddci2' \
      > /runvdr.sh && chmod +x /runvdr.sh

# -----------------------------------------------------------------------------
# Runtime
# USER vdr: Debian creates the vdr user during package installation (video group).
# If DVB devices in the container do not have permissions: in compose
# set "group_add: [video]" or temporarily remove the block for testing.
# -----------------------------------------------------------------------------
USER vdr

EXPOSE 2004 3000 6419 8001 8002 8008 34890

# restfulapi as health indicator: if port 8002 responds, VDR is running
HEALTHCHECK --interval=60s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -fsS http://localhost:8002/ > /dev/null || exit 1

ENTRYPOINT ["/runvdr.sh"]
