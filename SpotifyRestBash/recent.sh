#set -x

. ./callcurl.sh
. ./formatutils.sh
. ./contextinfo.sh

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


QUIET=Y

function recentInfoItem {
	MY_RECENT_ITEM_JSON="$1"
	MY_LAST_CONTEXT_ID="$2"

	PLAYED_AT=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".played_at")
	PLAYED_AT2=$(printf "%-19.19s" "$PLAYED_AT" | tr 'T' ' ')

	TRACK_NAME=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".track.name" | declutterNames)
	ALBUM_NAME=$(echo "$MY_RECENT_ITEM_JSON" | jq -r ".track.album.name" | declutterNames)
	ARTIST_NAMES=$(echo "$MY_RECENT_ITEM_JSON" | jq -cjr "[ .track.artists[].name ]" | declutterArtists)

	CONTEXT_JSON=$(echo "$MY_RECENT_ITEM_JSON" | jq ".context")
	LOOKUP_CONTEXT_DETAILS=N
	contextInfo "${CONTEXT_JSON}" "CHECK_ID" "$MY_LAST_CONTEXT_ID"
	CONTEXT_MAIN_NAME=$(echo "$CONTEXT_MAIN_NAME" | declutterNames)
}

function declutterNames {
	read SOURCE
	SOURCE="${SOURCE/- Live}"
	SOURCE="${SOURCE/\[Live\]}"
	SOURCE="${SOURCE/\(Live\)}"
	echo "$SOURCE"
}

function declutterArtists {
	read SOURCE
	SOURCE="${SOURCE/Wolfgang Amadeus Mozart/Mozart}"
	SOURCE="${SOURCE/George Fr[ie]deric Handel/Handel}"
	SOURCE="${SOURCE/Jean-Philippe Rameau/Rameau}"
	SOURCE="${SOURCE/Hector Berlioz/Berlioz}"
	SOURCE="${SOURCE/Henry Purcell/Purcell}"
	SOURCE="${SOURCE//\"}"
	echo "$SOURCE"
}

function calcPrintfLen {
	local REQUIRED_CHAR_LEN="$1"
	local VALUE="$2"
	local FROM_RIGHT="${3:-N}"

	if [[ $FROM_RIGHT == "Y" ]]
	then
		local VALUE_LENGTH=${#VALUE}
		if [[ $VALUE_LENGTH -gt $REQUIRED_CHAR_LEN ]] 
		then
			let START_POS=$((VALUE_LENGTH-REQUIRED_CHAR_LEN))
		else
			let START_POS=0
		fi
		local TRUNC_VALUE="${VALUE:${START_POS}:${REQUIRED_CHAR_LEN}}"	
		FROM_RIGHT_VALUE="${TRUNC_VALUE}"
	else
		local TRUNC_VALUE="${VALUE:0:${REQUIRED_CHAR_LEN}}"	# Produces value truncated to this number of characters (not bytes)
	fi

	# Determine the length of the field in characters and bytes 
	local CHAR_LENGTH=${#TRUNC_VALUE}
	local BYTE_LENGTH=$(echo -n "$TRUNC_VALUE" | wc -c)

	# What is the difference in the byte and character lengths ?
	let EXTRA_LENGTH=$((BYTE_LENGTH - CHAR_LENGTH))

	# Use this difference to work out what field length to use in a printf %*.*s formatting command to produce the desired
	# character length display output
	let PRINTF_FIELD_LENGTH=$((REQUIRED_CHAR_LEN+EXTRA_LENGTH))
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
	# RECENT=$(cat ${OUTDIR}/recent.json | jq -r '.items[] | .played_at+" - "+.context.type+" - "+.track.name+" - "+.track.album.name')
	# echo "${RECENT}"

	JSON=$(cat "${OUTDIR}/recent.json")
	RECENT_TRACK_COUNT=$(echo "$JSON" | jq -r '.items | length')

	if [[ $RECENT_TRACK_COUNT -eq 0 ]]
	then
		echo "- no recent items found"
	else
		echo "Found $RECENT_TRACK_COUNT recent tracks:"
		echo

		CONTEXT_LENGTH=10
		CONTEXT_NAME_FIELD_LENGTH=38
		let TRACK_FIELD_LENGTH=38
		ALBUM_FIELD_LENGTH=38
		ARTIST_FIELD_LENGTH=38
		printf "%-19s %-*.*s %-*.*s   %-*.*s   %-*.*s   %-*.*s\n" \
			"Played at" \
			$CONTEXT_LENGTH $CONTEXT_LENGTH "Context" \
			$CONTEXT_NAME_FIELD_LENGTH $CONTEXT_NAME_FIELD_LENGTH "Context Name" \
			$TRACK_FIELD_LENGTH $TRACK_FIELD_LENGTH "Track name" \
			$ALBUM_FIELD_LENGTH $ALBUM_FIELD_LENGTH "Album name" \
			$ARTIST_FIELD_LENGTH $ARTIST_FIELD_LENGTH "Artist(s)"
		printf "%-19s %-*.*s %-*.*s   %-*.*s   %-*.*s   %-*.*s\n" \
			"=========" \
			$CONTEXT_LENGTH $CONTEXT_LENGTH "=======" \
			$CONTEXT_NAME_FIELD_LENGTH $CONTEXT_NAME_FIELD_LENGTH "============" \
			$TRACK_FIELD_LENGTH $TRACK_FIELD_LENGTH "==========" \
			$ALBUM_FIELD_LENGTH $ALBUM_FIELD_LENGTH "==========" \
			$ARTIST_FIELD_LENGTH $ARTIST_FIELD_LENGTH "========="

		LAST_CONTEXT_ID="-"
		declare -i RECENT_TRACK_NO=1
		while [[ $RECENT_TRACK_NO -le $RECENT_TRACK_COUNT ]]
		do
			declare -i TRACK_INDEX=$RECENT_TRACK_NO-1
			ITEM_JSON=$(echo $JSON | jq ".items[${TRACK_INDEX}]")
			recentInfoItem "${ITEM_JSON}" "$LAST_CONTEXT_ID"

			if [[ "$LAST_CONTEXT_ID" == "${CONTEXT_ID}" ]]
			then
				DISPLAY_CONTEXT_ID=""				
				DISPLAY_CONTEXT_NAME=""				
			else
				DISPLAY_CONTEXT_ID="${CONTEXT_ID}"				
				DISPLAY_CONTEXT_NAME="$CONTEXT_MAIN_NAME"				
			fi
			LAST_CONTEXT_ID="${CONTEXT_ID}"
			if [[ "$CONTEXT_TYPE" == "null" ]]
			then
				CONTEXT_TYPE="-"	# Spotify's choosing a song after a playlist/album finishes
			fi
	
			# Printf %20.20s prints 20 bytes of characters, so for non-ASCII text, the amount printed will not align to the intended 20-character width field.
			# So make field widths dynamic, allowing for extra characters. Can do this because $# returns character count whereas wc -c returns byte count. Can use the
			# difference to work out how much to adjust the printf width by, and then make this variable via %*.*s. 
			#

			calcPrintfLen $CONTEXT_NAME_FIELD_LENGTH "${DISPLAY_CONTEXT_NAME}"
			CONTEXT_NAME_PRINTF_FIELD_LENGTH=$PRINTF_FIELD_LENGTH

			# If continuing with an album context, give more space to the track field and less to the album name (which is just a repeat)
			USE_FROM_RIGHT=N
			TRACK_FIELD_LENGTH_TO_USE=TRACK_FIELD_LENGTH
			ALBUM_FIELD_LENGTH_TO_USE=ALBUM_FIELD_LENGTH
			if [[ "$CONTEXT_TYPE" == "album" ]]
			then
				let TRACK_FIELD_LENGTH_TO_USE=$((TRACK_FIELD_LENGTH+ALBUM_FIELD_LENGTH))
				ALBUM_FIELD_LENGTH_TO_USE=0			
				USE_FROM_RIGHT=Y
			fi

			calcPrintfLen $TRACK_FIELD_LENGTH_TO_USE "${TRACK_NAME}" "$USE_FROM_RIGHT"
			TRACK_PRINTF_FIELD_LENGTH=$PRINTF_FIELD_LENGTH
			if [[ "$CONTEXT_TYPE" == "album" ]]
			then
				:
				TRACK_NAME="$FROM_RIGHT_VALUE"
			fi
			
			calcPrintfLen $ALBUM_FIELD_LENGTH_TO_USE "${ALBUM_NAME}"
			ALBUM_PRINTF_FIELD_LENGTH=$PRINTF_FIELD_LENGTH
			
			ARTIST_NAMES=$(removeSurroundingSquareBrackets "${ARTIST_NAMES}")
			calcPrintfLen $ARTIST_FIELD_LENGTH "${ARTIST_NAMES}"
			ARTIST_PRINTF_FIELD_LENGTH=$PRINTF_FIELD_LENGTH
			
			printf "%-19s %-*.*s %-*.*s   %-*.*s   %-*.*s   %-*.*s\n" "${PLAYED_AT2}" \
			$CONTEXT_LENGTH $CONTEXT_LENGTH "${CONTEXT_TYPE}" \
			$CONTEXT_NAME_PRINTF_FIELD_LENGTH $CONTEXT_NAME_PRINTF_FIELD_LENGTH "${DISPLAY_CONTEXT_NAME}" \
			$TRACK_PRINTF_FIELD_LENGTH $TRACK_PRINTF_FIELD_LENGTH "${TRACK_NAME}" \
			$ALBUM_PRINTF_FIELD_LENGTH $ALBUM_PRINTF_FIELD_LENGTH "${ALBUM_NAME}" \
			$ARTIST_PRINTF_FIELD_LENGTH $ARTIST_PRINTF_FIELD_LENGTH "${ARTIST_NAMES}"

			let RECENT_TRACK_NO=RECENT_TRACK_NO+1
		done
	fi

fi

