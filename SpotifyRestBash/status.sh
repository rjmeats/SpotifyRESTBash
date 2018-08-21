#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/status"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

QUIET=Y

######################################################################################

# Process 'device object' JSON and extract some fields from it into variables. The
# device JSON is passed in as a parameter
#
# Example:
# {
# 	"id" : "xxxxxxxxx",
# 	"is_active" : true,
# 	"is_private_session" : false,
# 	"is_restricted" : false,
# 	"name" : "LAPTOP-XXXXXXX",
# 	"type" : "Computer",
# 	"volume_percent" : 38
# }

function deviceInfo {
	MY_DEVICE_JSON=$1
	DEVICE_ID=$(echo "$MY_DEVICE_JSON" | jq -r ".id")
	DEVICE_NAME=$(echo "$MY_DEVICE_JSON" | jq -r ".name")
	DEVICE_TYPE=$(echo "$MY_DEVICE_JSON" | jq -r ".type")
	DEVICE_VOLUME=$(echo "$MY_DEVICE_JSON" | jq -r ".volume_percent")
	DEVICE_ACTIVE=$(echo "$MY_DEVICE_JSON" | jq -r ".is_active")
	if [[ $DEVICE_ACTIVE == "true" ]]
	then
		DEVICE_ACTIVE="yes"
	else
		DEVICE_ACTIVE="no"
	fi
}

# Process 'device object' JSON and extract some fields from it into variables. The
# device JSON is passed in as a parameter
#
# Example
#
# {
#	"external_urls" : {
#		"spotify" : "https://open.spotify.com/user/spotify/playlist/XXXXXXXX"
#	},
#	"href" : "https://api.spotify.com/v1/users/spotify/playlists/XXXXXXXX",
#	"type" : "playlist",
#	"uri" : "spotify:user:spotify:playlist:XXXXXXXX"
# }

function contextInfo {
	MY_CONTEXT_JSON="$1"
	GET_CONTEXT_DETAIL=$2
	CONTEXT_TYPE=$(echo "$MY_CONTEXT_JSON" | jq -r ".type")
	CONTEXT_HREF=$(echo "$MY_CONTEXT_JSON" | jq -r ".href")
	CONTEXT_URI=$(echo "$MY_CONTEXT_JSON" | jq -r ".uri")
	CONTEXT_EXTERNAL_URL=$(echo "$MY_CONTEXT_JSON" | jq -r ".external_urls.spotify")
	CONTEXT_ID="${CONTEXT_URI##*:}"

	if [[ $GET_CONTEXT_DETAIL == "Y" || $GET_CONTEXT_DETAIL == "y" ]]
	then
		if [[ $CONTEXT_TYPE == "playlist" ]]
		then
			PLAYLISTS_ENDPOINT="v1/playlists/${CONTEXT_ID}"
			callCurl "GET" "${PLAYLISTS_ENDPOINT}" "${OUTDIR}/playlist_context.json" $QUIET 
			if [[ $? -ne 0 ]]
			then
				echo "Get playlist API call failed"
			elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
			then
				echo "Unexpected HTTP Response fetching playlist context: ${CURL_HTTP_RESPONSE}"
			else
				PLAYLIST_CONTEXT_JSON=$(cat "${OUTDIR}/playlist_context.json")
				PLAYLIST_CONTEXT_NAME=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".name")
				PLAYLIST_CONTEXT_DESCRIPTION=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".description")
				PLAYLIST_CONTEXT_PUBLIC=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".public")
				PLAYLIST_CONTEXT_OWNER_NAME=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".owner.display_name")
				PLAYLIST_CONTEXT_TRACK_COUNT=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".tracks.total")
				PLAYLIST_CONTEXT_FOLLOWER_COUNT=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".followers.total")
			fi
		fi
	fi
}

######################################################################################

# NB devices endpoint doesn't seem to return info about phone, only desktop Windows app, Web player in chrome. Devices are only
# listed if they are opened (not necessarily playing). So can list desktop app and Chrome browser as two devices, but won't show phone app (and
# presumably not Sonos etc either.)

echo
date

DEVICES_ENDPOINT="v1/me/player/devices"
callCurl "GET" "${DEVICES_ENDPOINT}" "${OUTDIR}/user_devices.json" ${QUIET}

if [[ $? -ne 0 ]]
then
	echo "Get devices API call failed"
	exit 1
elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
then
	echo "Unexpected HTTP Response: ${CURL_HTTP_RESPONSE}"
	exit 1
else
	echo 
	JSON=$(cat "${OUTDIR}/user_devices.json")
	DEVICE_COUNT=$(echo $JSON | jq -r '.devices | length')

	if [[ $DEVICE_COUNT -eq 0 ]]
	then
		echo "- no devices found"
	else
		echo "Found $DEVICE_COUNT device(s):"
		echo
		declare -i DEV_NO=1
		printf "%-8s %-35s %6s   %s\n" "Active ?" "Device" "Volume" "Spotify Device ID"
		printf "%-8s %-35s %6s   %s\n" "========" "===================================" "======" "========================================"
		while [[ $DEV_NO -le $DEVICE_COUNT ]]
		do
			declare -i DEV_INDEX=$DEV_NO-1
			DEV_JSON=$(echo $JSON | jq ".devices[${DEV_INDEX}]")
			deviceInfo "${DEV_JSON}"
			printf "%-8s %-35s %4d %%   %s\n" "$DEVICE_ACTIVE" "$DEVICE_TYPE/$DEVICE_NAME" "$DEVICE_VOLUME" "$DEVICE_ID"
			let DEV_NO=DEV_NO+1
		done | sort -r
	fi

	echo
	echo "(NB Phone apps do not appear in the devices list)"
fi

######################################################################################

# The 'player' API provides information about the current playback situation, including
# the device and the currently playing track. (A separate API provides just the track.)

PLAYER_ENDPOINT="v1/me/player"
callCurl "GET" "${PLAYER_ENDPOINT}" "${OUTDIR}/user_player.json" "${QUIET}"

if [[ $? -ne 0 ]]
then
	echo "Get current playback API call failed"
	echo 
	echo "Podcast playing ?"
	echo
	exit 1
elif [[ ${CURL_HTTP_RESPONSE} -eq 204 ]]
then
	echo
	echo "Nothing playing"
elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
then
	echo "Unexpected HTTP Response: ${CURL_HTTP_RESPONSE}"
	exit 1
else
	echo 
	JSON=$(cat "${OUTDIR}/user_player.json")

	# Pull out device info
	DEV_JSON=$(echo $JSON | jq ".device")
	deviceInfo "${DEV_JSON}"

	# And some other high-level player info not in the device object itself
	PLAYER_IS_PLAYING=$(echo $JSON | jq -r ".is_playing")
	if [[ $PLAYER_IS_PLAYING == "true" ]]
	then
		PLAYER_IS_PLAYING="yes"
	else
		PLAYER_IS_PLAYING="no"
	fi
	SHUFFLE_STATE=$(echo $JSON | jq -r ".shuffle_state")
	if [[ $SHUFFLE_STATE == "true" ]]
	then
		SHUFFLE_STATE="on"
	else
		SHUFFLE_STATE="off"
	fi

	REPEAT_STATE=$(echo $JSON | jq -r ".repeat_state")

	echo "Current player info:"
	echo
	echo "- device:         ${DEVICE_TYPE}/${DEVICE_NAME}"
	echo "- ID:             $DEVICE_ID"
	echo "- volume level:   $DEVICE_VOLUME %"
	echo "- is active?:     $DEVICE_ACTIVE"
	echo "- is playing?:    $PLAYER_IS_PLAYING"
	echo "- shuffle state:  $SHUFFLE_STATE"
	echo "- repeat state:   $REPEAT_STATE"

	# Context Info of current track 
	CONTEXT_JSON=$(echo $JSON | jq ".context")
	GET_DETAIL="Y"
	contextInfo "${CONTEXT_JSON}" ${GET_DETAIL}

	echo
	echo "Current track context:"
	echo
	if [[ $CONTEXT_TYPE == "playlist" ]]
	then
		echo "- type:        $CONTEXT_TYPE"
		echo "- ID:          $CONTEXT_ID"
		echo "- name:        $PLAYLIST_CONTEXT_NAME"
		echo "- owner:       $PLAYLIST_CONTEXT_OWNER_NAME"
		echo "- public:      $PLAYLIST_CONTEXT_PUBLIC"
		echo "- tracks:      $PLAYLIST_CONTEXT_TRACK_COUNT"
		echo "- followers:   $PLAYLIST_CONTEXT_FOLLOWER_COUNT"
		if [[ ! -z $PLAYLIST_CONTEXT_DESCRIPTION ]]
		then
			echo "- description: $PLAYLIST_CONTEXT_DESCRIPTION"
		fi
	else
# Todo - other contexts - artist, album
	echo "- type:           $CONTEXT_TYPE"
	echo "- href:           $CONTEXT_HREF"
	echo "- uri:            $CONTEXT_URI"
	echo "- external URL:   $CONTEXT_EXTERNAL_URL"
	echo "- context ID:     $CONTEXT_ID"
	fi

# Todo Current track has its own album (+album-type) and artist(s) info 

	# Track


#	echo
#	INFO=$(echo ${OJ} | jq "{ device: .device.name, playing: .is_playing, album: .item.album.name, item: .item.name }")
#	echo "Player info is ${INFO}"

fi

######################################################################################

#	echo
#	cat "${OUTDIR}/user_devices.json" | 
#		jq -r '.devices[] | .id + " : " + .type + " : " + .name + " : " + if .is_active == true then "active" else "inactive" end + " : " + (.volume_percent | tostring)'

# Show currently playing
# Not the normal paging structure, so below doesn't do any next processing

exit 0


######################################################################################

# Show recently played
# Not the normal paging structure, so below doesn't do any next processing

#RECENTLY_PLAYED_ENDPOINT="v1/me/player/recently-played"
#callCurlPaging "GET" "${RECENTLY_PLAYED_ENDPOINT}" "${OUTDIR}/user_recently_played.json" 100
#
#if [[ $? -ne 0 ]]
#then
#	echo "Get recently-played call failed"
#else
#	echo
#	RECENT=$(cat ${OUTDIR}/user_recently_played.json | jq '.items[] | .played_at+" - "+.track.name')
#	echo "${RECENT}"
#fi
#
