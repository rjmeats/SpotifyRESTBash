
function contextInfo {
	MY_CONTEXT_JSON="$1"
	GET_CONTEXT_DETAIL="$2"
	MY_CHECK_CONTEXT_ID="$3"
	CONTEXT_TYPE=$(echo "$MY_CONTEXT_JSON" | jq -r ".type")
	CONTEXT_HREF=$(echo "$MY_CONTEXT_JSON" | jq -r ".href")
	CONTEXT_URI=$(echo "$MY_CONTEXT_JSON" | jq -r ".uri")
	CONTEXT_EXTERNAL_URL=$(echo "$MY_CONTEXT_JSON" | jq -r ".external_urls.spotify")
	CONTEXT_ID="${CONTEXT_URI##*:}"
	CONTEXT_MAIN_NAME=""

	if [[ "$CONTEXT_TYPE" == "playlist_v2" ]]
	then
		CONTEXT_TYPE="playlist"
	fi		

	if [[ "$GET_CONTEXT_DETAIL" == "CHECK_ID" ]]
	then
		if [[ "$CONTEXT_ID" == "$MY_CHECK_CONTEXT_ID" ]]
		then
			GET_CONTEXT_DETAIL="N"
		else
			GET_CONTEXT_DETAIL="Y"
		fi
	fi

	#echo "*** Get Detail = $GET_CONTEXT_DETAIL ***"

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
				
				CONTEXT_MAIN_NAME="$PLAYLIST_CONTEXT_NAME"
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
				CONTEXT_MAIN_NAME="$ARTIST_CONTEXT_NAME"
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
				CONTEXT_MAIN_NAME="$ALBUM_CONTEXT_NAME"
			fi
		fi
	fi
}


