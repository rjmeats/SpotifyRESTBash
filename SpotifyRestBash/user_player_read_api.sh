#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/player_read"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

######################################################################################

# Show player

PLAYER_ENDPOINT="v1/me/player"
callCurl "GET" "${PLAYER_ENDPOINT}" "${OUTDIR}/user_player.json"

if [[ $? -ne 0 ]]
then
	echo "Get player call failed"
else
	if grep HTTP "${HEADER_OUTFILE}" | grep -q 204
	then
		echo 
		echo "HTTP 204 - nothing playing"
		echo
		exit
	fi

	echo
	INFO=$(cat ${OUTDIR}/user_player.json | jq "{ device: .device.name, playing: .is_playing, album: .item.album.name, item: .item.name }")
	echo "Player info is ${INFO}"

fi

######################################################################################

# Show devices

DEVICES_ENDPOINT="v1/me/player/devices"
callCurl "GET" "${DEVICES_ENDPOINT}" "${OUTDIR}/user_devices.json"

if [[ $? -ne 0 ]]
then
	echo "Get devices call failed"
else
	cat "${OUTDIR}/user_devices.json"
fi

######################################################################################

# Show currently playing
# Not the normal paging structure, so below doesn't do any next processing

CURRENTLY_PLAYING_ENDPOINT="v1/me/player/currently-playing"
callCurl "GET" "${CURRENTLY_PLAYING_ENDPOINT}" "${OUTDIR}/user_currently_playing.json"

if [[ $? -ne 0 ]]
then
	echo "Get currntly-playing call failed"
else
	echo
	PLAYING=$(cat ${OUTDIR}/user_currently_playing.json | jq "{ album: .item.album.name, item: .item.name, artist0: .item.artists[0].name, artist1: .item.artists[1].name }")
	echo "${PLAYING}"
fi

sleep 5

######################################################################################

# Show recently played
# Not the normal paging structure, so below doesn't do any next processing

RECENTLY_PLAYED_ENDPOINT="v1/me/player/recently-played"
#set -x
callCurlPaging "GET" "${RECENTLY_PLAYED_ENDPOINT}" "${OUTDIR}/user_recently_played.json" 100

if [[ $? -ne 0 ]]
then
	echo "Get recently-played call failed"
else
	echo
	RECENT=$(cat ${OUTDIR}/user_recently_played.json | jq '.items[] | .played_at+" - "+.track.name')
	echo "${RECENT}"
fi

