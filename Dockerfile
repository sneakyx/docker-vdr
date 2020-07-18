FROM ubuntu:18.04

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="sneaky version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sneaky"

# upgrade and install vdr and dvb-apps
RUN apt-get update && apt-get upgrade -y
RUN apt-get install vdr dvb-apps -y

# install vdr plugins
RUN apt-get install vdradmin-am vdr-plugin-epgsearch vdr-plugin-streamdev-server vlc \
   vdr-plugin-vnsiserver vdr-plugin-live vdr-plugin-epgsearch -y
RUN echo 'ENABLED="1"' >> /etc/default/vdradmin-am
# others action
RUN mkdir /recordings

# copy local files
ADD run.sh /run.sh
RUN chmod +x /run.sh

# ports and volumes
EXPOSE 8008 34890
VOLUME /recordings

CMD ["/run.sh"]
