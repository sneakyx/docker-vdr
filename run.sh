#!/bin/sh

/usr/bin/vdr -Plive -Pstreamdev-server -Pxvdr -Pvnsiserver -Psatip -P 'epgsearch --config=/etc/vdr/plugins/epgsearch' -P 'xineliboutput --local=none --remote=37890' -v /recordings
