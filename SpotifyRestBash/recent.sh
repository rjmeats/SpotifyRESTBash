#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/recent"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

function recentInfo {
	MY_RECENT_ITEM_JSON=$1
	PLAYED_AT=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".played_at")
	CONTEXT_TYPE=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".context.type")
	if [[ "$CONTEXT_TYPE" == "null" ]]
	then
		CONTEXT_TYPE="?"
		CONTEXT_URI=""
		CONTEXT_ID=""
	else
		if [[ "$CONTEXT_TYPE" == "playlist_v2" ]]
		then
			CONTEXT_TYPE="playlist"
		fi
		CONTEXT_URI=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".context.uri")
		CONTEXT_ID="${CONTEXT_URI##*:}"
	fi
	
	TRACK_NAME=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".track.name")
	ALBUM_NAME=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".track.album.name")
}

######################################################################################

# Show recently played
# Request 100 but the API only returns 50 (regardless of batch size/next processing)

RECENTLY_PLAYED_ENDPOINT="v1/me/player/recently-played"
callCurlPaging "GET" "${RECENTLY_PLAYED_ENDPOINT}" "${OUTDIR}/recent.json" 50

if [[ $? -ne 0 ]]
then
	echo "Get recently-played call failed"
	exit 1
elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
then
	echo "Unexpected HTTP Response: ${CURL_HTTP_RESPONSE}"
	exit 1
else
	echo
	echo "Recently played tracks:"
	echo
	RECENT=$(cat ${OUTDIR}/recent.json | jq -r '.items[] | .played_at+" - "+.context.type+" - "+.track.name+" - "+.track.album.name')
	echo "${RECENT}"

	JSON=$(cat "${OUTDIR}/recent.json")
	RECENT_TRACK_COUNT=$(echo "$JSON" | jq -r '.items | length')

	if [[ $RECENT_TRACK_COUNT -eq 0 ]]
	then
		echo "- no recent items found"
	else
		echo "Found $RECENT_TRACK_COUNT recent tracks:"
		echo
		declare -i RECENT_TRACK_NO=1
		printf "%-24s %-12s %-20.20s %-40.40s   %-40.40s\n" "Played at" "Context" "Context ID" "Track name" "Album name"
		printf "%-24s %-12s %-20.20s %-40.40s   %-40.40s\n" "=========" "=======" "==========" "==========" "=========="
		LAST_CONTEXT_ID="-"
		while [[ $RECENT_TRACK_NO -le $RECENT_TRACK_COUNT ]]
		do
			declare -i TRACK_INDEX=$RECENT_TRACK_NO-1
			ITEM_JSON=$(echo $JSON | jq ".items[${TRACK_INDEX}]")
			recentInfo "${ITEM_JSON}"
			if [[ "$LAST_CONTEXT_ID" == "${CONTEXT_ID}" ]]
			then
				DISPLAY_CONTEXT_ID=""				
			else
				DISPLAY_CONTEXT_ID="${CONTEXT_ID}"				
			fi
			LAST_CONTEXT_ID="${CONTEXT_ID}"

			printf "%-24s %-12s %-20.20s %-40.40s   %-40.40s\n" "${PLAYED_AT}" "${CONTEXT_TYPE}" "${DISPLAY_CONTEXT_ID}" "${TRACK_NAME}" "${ALBUM_NAME}"
			let RECENT_TRACK_NO=RECENT_TRACK_NO+1
		done
	fi

fi

