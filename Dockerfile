FROM ubuntu:18.04

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="abobier version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="abobier"

# upgrade and install vdr and dvb-apps
RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install vdr dvb-apps -y

# install vdr plugins
RUN apt-get install vdr-plugin-vnsiserver vdr-plugin-live vdr-plugin-streamdev-server vdr-plugin-epgsearch -y

# ports and volumes
EXPOSE 8008 34890
VOLUME /config /recordings
