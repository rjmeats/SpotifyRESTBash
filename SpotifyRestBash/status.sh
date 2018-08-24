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
				PLAYLIST_CONTEXT_SPOTIFY_URL=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".external_urls.spotify")
				PLAYLIST_CONTEXT_DESCRIPTION=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".description")
				PLAYLIST_CONTEXT_PUBLIC=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".public")
				PLAYLIST_CONTEXT_OWNER_NAME=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".owner.display_name")
				PLAYLIST_CONTEXT_TRACK_COUNT=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".tracks.total")
				PLAYLIST_CONTEXT_FOLLOWER_COUNT=$(echo "$PLAYLIST_CONTEXT_JSON" | jq -r ".followers.total")
			fi
		fi

		if [[ $CONTEXT_TYPE == "artist" ]]
		then
			PLAYLISTS_ENDPOINT="v1/artists/${CONTEXT_ID}"
			callCurl "GET" "${PLAYLISTS_ENDPOINT}" "${OUTDIR}/artist_context.json" $QUIET 
			if [[ $? -ne 0 ]]
			then
				echo "Get artist API call failed"
			elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
			then
				echo "Unexpected HTTP Response fetching artist context: ${CURL_HTTP_RESPONSE}"
			else
				ARTIST_CONTEXT_JSON=$(cat "${OUTDIR}/artist_context.json")
				ARTIST_CONTEXT_NAME=$(echo "$ARTIST_CONTEXT_JSON" | jq -r ".name")
				ARTIST_CONTEXT_SPOTIFY_URL=$(echo "$ARTIST_CONTEXT_JSON" | jq -r ".external_urls.spotify")
				ARTIST_CONTEXT_POPULARITY=$(echo "$ARTIST_CONTEXT_JSON" | jq -r ".popularity")
				ARTIST_CONTEXT_FOLLOWERS_COUNT=$(echo "$ARTIST_CONTEXT_JSON" | jq -r ".followers.total")
				ARTIST_CONTEXT_GENRES=$(echo "$ARTIST_CONTEXT_JSON" | jq -cr ".genres")
			fi
		fi

		if [[ $CONTEXT_TYPE == "album" ]]
		then
			PLAYLISTS_ENDPOINT="v1/albums/${CONTEXT_ID}"
			callCurl "GET" "${PLAYLISTS_ENDPOINT}" "${OUTDIR}/album_context.json" $QUIET 
			if [[ $? -ne 0 ]]
			then
				echo "Get album API call failed"
			elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
			then
				echo "Unexpected HTTP Response fetching album context: ${CURL_HTTP_RESPONSE}"
			else
				ALBUM_CONTEXT_JSON=$(cat "${OUTDIR}/album_context.json")
				ALBUM_CONTEXT_NAME=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".name")
				ALBUM_CONTEXT_SPOTIFY_URL=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".external_urls.spotify")
				ALBUM_CONTEXT_ALBUM_TYPE=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".album_type")
				ALBUM_CONTEXT_LABEL=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".label")
				ALBUM_CONTEXT_TRACK_COUNT=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".total_tracks")
				ALBUM_CONTEXT_POPULARITY=$(echo "$ALBUM_CONTEXT_JSON" | jq -r ".popularity")
				ALBUM_CONTEXT_GENRES=$(echo "$ALBUM_CONTEXT_JSON" | jq -cr ".genres")
				ALBUM_CONTEXT_ARTIST_NAMES=$(echo "$ALBUM_CONTEXT_JSON" | jq -cjr "[ .artists[].name ]")
			fi
		fi
	fi
}

function trackInfo {
	MY_TRACK_JSON="$1"
	GET_TRACK_DETAIL=$2
	TRACK_NAME=$(echo "$MY_TRACK_JSON" | jq -r ".name")
	TRACK_ID=$(echo "$MY_TRACK_JSON" | jq -r ".id")
	TRACK_ARTIST_NAMES=$(echo "$MY_TRACK_JSON" | jq -cjr "[ .artists[].name ]")
	TRACK_POPULARITY=$(echo "$MY_TRACK_JSON" | jq -r ".popularity")
	TRACK_DURATION_MS=$(echo "$MY_TRACK_JSON" | jq -r ".duration_ms")
	TRACK_DISK_NUMBER=$(echo "$MY_TRACK_JSON" | jq -r ".disc_number")
	TRACK_NUMBER=$(echo "$MY_TRACK_JSON" | jq -r ".track_number")
	TRACK_ALBUM_NAME=$(echo "$MY_TRACK_JSON" | jq -r ".album.name")
	TRACK_ALBUM_ID=$(echo "$MY_TRACK_JSON" | jq -r ".album.id")
	TRACK_ALBUM_SPOTIFY_URL=$(echo "$MY_TRACK_JSON" | jq -r ".album.external_urls.spotify")
	TRACK_ALBUM_TRACK_COUNT=$(echo "$MY_TRACK_JSON" | jq -r ".album.total_tracks")

	if [[ $GET_TRACK_DETAIL == "Y" || $GET_TRACK_DETAIL == "y" ]]
	then
		TRACK_FEATURES_ENDPOINT="v1/audio-features/${TRACK_ID}"
		callCurl "GET" "${TRACK_FEATURES_ENDPOINT}" "${OUTDIR}/track_features.json" $QUIET 
		if [[ $? -ne 0 ]]
		then
			echo "Get track features API call failed"
		elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
		then
			echo "Unexpected HTTP Response fetching track features: ${CURL_HTTP_RESPONSE}"
		else
			TRACK_FEATURES_JSON=$(cat "${OUTDIR}/track_features.json")
			TRACK_FEATURES_DANCEABILITY=$(echo "$TRACK_FEATURES_JSON" | jq -r ".danceability")
			TRACK_FEATURES_ENERGY=$(echo "$TRACK_FEATURES_JSON" | jq -r ".energy")
			TRACK_FEATURES_KEY=$(echo "$TRACK_FEATURES_JSON" | jq -r ".key")
			TRACK_FEATURES_LOUDNESS=$(echo "$TRACK_FEATURES_JSON" | jq -r ".loudness")
			TRACK_FEATURES_MODE=$(echo "$TRACK_FEATURES_JSON" | jq -r ".mode")
			TRACK_FEATURES_SPEECHINESS=$(echo "$TRACK_FEATURES_JSON" | jq -r ".speechiness")
			TRACK_FEATURES_ACOUSTICNESS=$(echo "$TRACK_FEATURES_JSON" | jq -r ".acousticness")
			TRACK_FEATURES_INSTRUMENTALNESS=$(echo "$TRACK_FEATURES_JSON" | jq -r ".instrumentalness")
			TRACK_FEATURES_LIVENESS=$(echo "$TRACK_FEATURES_JSON" | jq -r ".liveness")
			TRACK_FEATURES_VALENCE=$(echo "$TRACK_FEATURES_JSON" | jq -r ".valence")
			TRACK_FEATURES_TEMPO=$(echo "$TRACK_FEATURES_JSON" | jq -r ".tempo")
			TRACK_FEATURES_TIME_SIGNATURE=$(echo "$TRACK_FEATURES_JSON" | jq -r ".time_signature")
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
		echo "- context type:          $CONTEXT_TYPE"
		echo "- ID:                    $CONTEXT_ID"
		echo "- name:                  $PLAYLIST_CONTEXT_NAME"
		echo "- Spotify playlist URL:  $PLAYLIST_CONTEXT_SPOTIFY_URL"
		echo "- owner:                 $PLAYLIST_CONTEXT_OWNER_NAME"
		echo "- public:                $PLAYLIST_CONTEXT_PUBLIC"
		echo "- tracks:                $PLAYLIST_CONTEXT_TRACK_COUNT"
		echo "- followers:             $PLAYLIST_CONTEXT_FOLLOWER_COUNT"
		if [[ ! -z $PLAYLIST_CONTEXT_DESCRIPTION ]]
		then
			echo "- description: $PLAYLIST_CONTEXT_DESCRIPTION"
		fi
	elif [[ $CONTEXT_TYPE == "artist" ]]
	then
		echo "- context type:        $CONTEXT_TYPE"
		echo "- ID:                  $CONTEXT_ID"
		echo "- name:                $ARTIST_CONTEXT_NAME"				
		echo "- Spotify artist URL:  $ARTIST_CONTEXT_SPOTIFY_URL"
		echo "- genres:              $ARTIST_CONTEXT_GENRES"				
		echo "- followers:           $ARTIST_CONTEXT_FOLLOWERS_COUNT"
		echo "- popularity:          $ARTIST_CONTEXT_POPULARITY"
	elif [[ $CONTEXT_TYPE == "album" ]]
	then
		ARTISTS_NAMES=$(removeSurroundingSquareBrackets "${ALBUM_CONTEXT_ARTIST_NAMES}")
		echo "- context type:       $CONTEXT_TYPE"
		echo "- ID:                 $CONTEXT_ID"
		echo "- name:               $ALBUM_CONTEXT_NAME"				
		echo "- Spotify album URL:  $ARTIST_CONTEXT_SPOTIFY_URL"
		echo "- album type:         $ALBUM_CONTEXT_ALBUM_TYPE"				
		echo "- artists:            $ARTISTS_NAMES"				
		echo "- LABEL:              $ALBUM_CONTEXT_LABEL"				
		echo "- tracks:             $ALBUM_CONTEXT_TRACK_COUNT"				
		# echo "- genres:     # Not filled in by Spotify for albums
		echo "- popularity:         $ALBUM_CONTEXT_POPULARITY"
	else
		echo "- type:        $CONTEXT_TYPE"
		echo "- context ID:  $CONTEXT_ID"
	fi

	# Current track info
	TRACK_JSON=$(echo $JSON | jq ".item")

	if [[ "$TRACK_JSON" == "null" ]]
	then
		echo
		echo "No track currently playing"
	else
		PROGRESS_MS=$(echo $JSON | jq -r ".progress_ms")
		trackInfo "${TRACK_JSON}" "${GET_DETAIL}"

		ARTISTS_NAMES=$(removeSurroundingSquareBrackets "${TRACK_ARTIST_NAMES}")
		echo
		echo "Current track:"
		echo
		echo "- name:               $TRACK_NAME"
		echo "- id:                 $TRACK_ID"
		echo "- artist(s):          $ARTISTS_NAMES"
		echo "- popularity          $TRACK_POPULARITY"
		echo "- progress/duration   $PROGRESS_MS / $TRACK_DURATION_MS"
		echo "- album name:         $TRACK_ALBUM_NAME"
		echo "- album id:           $TRACK_ALBUM_ID"
		echo "- Spotify album URL:  $TRACK_ALBUM_SPOTIFY_URL"
		echo "- disk no:            $TRACK_DISK_NUMBER"
		echo "- track no:           $TRACK_NUMBER"
		echo "- tracks in album:    $TRACK_ALBUM_TRACK_COUNT"

		declare -i SECONDS_PLAYING SECONDS_TO_GO SECONDS_DURATION PERCENT_PLAYED
		let SECONDS_PLAYING=$PROGRESS_MS/1000
		let SECONDS_DURATION=$TRACK_DURATION_MS/1000
		let SECONDS_TO_GO=($TRACK_DURATION_MS - $PROGRESS_MS)/1000
		let PERCENT_PLAYED=SECONDS_PLAYING*100/SECONDS_DURATION

		echo
		echo "- playing for $SECONDS_PLAYING seconds out of $SECONDS_DURATION, ${PERCENT_PLAYED}% of track played, $SECONDS_TO_GO seconds to go"
		echo
		echo "Track 'Features':"
		echo
		echo "- danceability:        $TRACK_FEATURES_DANCEABILITY"
		echo "- energy:              $TRACK_FEATURES_ENERGY"
		echo "- speechiness:         $TRACK_FEATURES_SPEECHINESS"
		echo "- acousticness:        $TRACK_FEATURES_ACOUSTICNESS"
		echo "- instrumentalness:    $TRACK_FEATURES_INSTRUMENTALNESS"
		echo "- liveness:            $TRACK_FEATURES_LIVENESS"
		echo "- valence:             $TRACK_FEATURES_VALENCE"
		echo "- loudness:            $TRACK_FEATURES_LOUDNESS"
		echo "- mode:                $TRACK_FEATURES_MODE"
		echo "- key:                 $TRACK_FEATURES_KEY"
		echo "- tempo:               $TRACK_FEATURES_TEMPO"
		echo "- time signature:      $TRACK_FEATURES_TIME_SIGNATURE"
	fi

	# Show Audio features of current track ?
fi

######################################################################################
