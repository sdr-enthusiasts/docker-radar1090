#!/command/with-contenv bash
# shellcheck shell=bash disable=SC1091
# SC2015,SC2164,SC2068,SC2145,SC2120

source /scripts/common
s6wrap=(s6wrap --quiet --timestamps --prepend="$(basename "$0")")

#---------------------------------------------------------------------------------------------
# This repository, docker container, and accompanying scripts and documentation is
# Copyright (C) 2022-2023, Ramon F. Kolb (kx1t)
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
#
# Radar1090 is an ADS-B RADAR Feed Service
# Copyright (C) 2023 by Michael J. Tubby B.Sc. MIET G8TIC mik@tubby.org All Rights Reserved.
# No license to the "radar" binary and its source code is implied; contact the author for information.
#---------------------------------------------------------------------------------------------

# Healthcheck for autoheal. Returns 1 if $HEALTHFILE contains a number greater than 0
# This number is written by the watchdog service to ensure there's traffic flowing for radar1090

HEALTHFILE=/run/watchdog-log/health_failures_since_last_success
MEASURE_TIME="${MEASURE_TIME:-15}"              # how long we take samples to check data is flowing
MEASURE_INTERVAL="${MEASURE_INTERVAL:-300}"     # wait time between check runs
TRANSPORT_PROTOCOL="${TRANSPORT_PROTOCOL:-udp}" # [udp|tcp] the protocol used to transport data to the remote aggregator
TRANSPORT_PROTOCOL="${TRANSPORT_PROTOCOL,,}"

FAILURES_TO_GO_UNHEALTHY=3  # after this number of failures, the container will go unhealthy

IP_RESOLVE_HEALTHFILE=/run/watchdog-log/beastname_resolution_failures

# make sure the log files exists:
mkdir -p "$(dirname "$HEALTHFILE")"
mkdir -p "$(dirname "$IP_RESOLVE_HEALTHFILE")"
touch "$HEALTHFILE"
touch "$IP_RESOLVE_HEALTHFILE"

read -r flow_healthfailures < "$HEALTHFILE" || true
read -r ip_healthfailures < "$IP_RESOLVE_HEALTHFILE" || true

exitvalue=0
if [[ -n "$flow_healthfailures" ]] && (( flow_healthfailures >= FAILURES_TO_GO_UNHEALTHY )); then
    "${s6wrap[@]}" --args echo "UNHEALTHY: No data is flowing to ${RADARSERVER:-adsb-in.1090mhz.uk}:${RADARPORT:-5997}/${TRANSPORT_PROTOCOL:-udp} - failure count since last successful measurement is $flow_healthfailures"
    exitvalue=1
fi
if [[ -n "$ip_healthfailures" ]] && (( ip_healthfailures >= FAILURES_TO_GO_UNHEALTHY )); then
    "${s6wrap[@]}" --args echo "UNHEALTHY: Cannot resolve IP address for ${BEASTHOST:-ultrafeeder} - failure count since last successful measurement is $ip_healthfailures"
    exitvalue=1
fi

exit $exitvalue
