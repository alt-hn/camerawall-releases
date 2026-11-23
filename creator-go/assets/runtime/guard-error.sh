#!/bin/sh
# Last resort if the disk guard exits before it can display its own error.
. /usr/share/debconf/confmodule
cat >/tmp/camerawall-guard.templates <<'TEMPLATES'
Template: camerawall/guard-stopped
Type: error
Description: Disk preparation stopped unexpectedly
 Setup cannot continue safely. Photograph the log below before restarting.
TEMPLATES
debconf-loadtemplate camerawall /tmp/camerawall-guard.templates
db_input critical camerawall/guard-stopped
db_go
