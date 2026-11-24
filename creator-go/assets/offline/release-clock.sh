# Sourced by select-disk.sh after it verifies the USB and before partitioning.
. /camerawall/release.env
now=$(date -u +%s) || fail 'Cannot read the installer clock.'
if [ "$now" -lt "$CAMERAWALL_RELEASE_EPOCH" ]; then
 date -u -s "@$CAMERAWALL_RELEASE_EPOCH" >/dev/null || fail 'Cannot set the installer clock to the CameraWall release time.'
 # Debian's finish-install clock hook persists the corrected system time to the UTC RTC.
 db_set clock-setup/system-time-changed true
 logger -t camerawall "Advanced installer clock from $now to $CAMERAWALL_RELEASE_EPOCH (release $CAMERAWALL_VERSION)."
fi
