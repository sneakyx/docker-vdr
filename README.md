# docker-vdr
Docker repository for VDR

# create container (old version)
docker create --name=vdr -p 8008:8008 -p 34890:34890 --device /dev/dri:/dev/dri --device /dev/dvb:/dev/dvb -v /media/bighdd:/recordings sneaky/vdr 
