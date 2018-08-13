#set -x

. ./jqutils.sh
. ./callcurl.sh

OUTDIR="./output/search"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

# Page through a set of API responses, using Spotify's 'next' URL to fetch subsequent pages, until we reach the end or
# hit a specified maximum. Glue the output files produced into one big file.
function callCurlPaging() {

	local VERB="$1"
	local ENDPOINT="$2"
	local OUTFILE="$3"			# Expected to end .json and include path info

	declare -i MAXITEMS=${4:-100}		# Default to 100 items
	local BATCHSIZE=50			# Max allowed by API is 50

	ENDPOINT="${ENDPOINT}&limit=${BATCHSIZE}"

	if [[ -f ${OUTFILE} ]]
	then
		rm ${OUTFILE} 
	fi

	if [[ -f ${OUTFILE}.html ]]
	then
		rm ${OUTFILE}.html 
	fi

	HEADER_OUTFILE="${OUTFILE//'.json'/'.headers.txt'}"
	if [[ -f ${HEADER_OUTFILE} ]]
	then
		rm ${HEADER_OUTFILE} 
	fi

	REQUEST_OUTFILE="${OUTFILE//'.json'/'.request.txt'}"
	if [[ -f ${REQUEST_OUTFILE} ]]
	then
		rm ${REQUEST_OUTFILE} 
	fi

	local CONTINUE=Y
	declare -i ITEMS_SO_FAR=0
	declare -i ITEMS_RETURNED=0
	declare -i TOTAL_ITEMS=0
	declare -i CALL_COUNT=0
	local NEXT_URL=""

	local RETURN_STATUS=0

	while [[ ${CONTINUE} == "Y" ]]
	do
		let CALL_COUNT+=1
		local MY_OUTFILE=${OUTFILE}.${CALL_COUNT}
		local MY_HEADER_OUTFILE=${HEADER_OUTFILE}.${CALL_COUNT}
		local MY_REQUEST_OUTFILE=${REQUEST_OUTFILE}.${CALL_COUNT}

		callCurl "${VERB}" "${ENDPOINT}" "${MY_OUTFILE}" Y

		if [[ $? -eq 0 ]]
		then
			# Called Curl OK, 
			# Count items return
			# Expect the results to have only one of tracks, artists or albums, using the 'paging object' Spotify json structure.
			# How many items in the 'items' array ?
			ITEMS_RETURNED=$(cat ${MY_OUTFILE} | jq '.tracks.items, .artists.items, .albums.items | arrays | length')
			# How many total items found by this search ?
			TOTAL_ITEMS=$(cat ${MY_OUTFILE} | jq '.tracks.total?, .artists.total?, .albums.total? | numbers')
			let ITEMS_SO_FAR+=${ITEMS_RETURNED}
			echo "Call ${CALL_COUNT}: retrieved ${ITEMS_RETURNED} more items, ${ITEMS_SO_FAR} items so far out of ${TOTAL_ITEMS}"

			# Append file output
			cat ${MY_OUTFILE} >> $OUTFILE
			cat ${MY_HEADER_OUTFILE} >> $HEADER_OUTFILE
			cat ${MY_REQUEST_OUTFILE} >> $REQUEST_OUTFILE

			# Extract a next URL. null means we've got everything
			NEXT_URL=$(cat ${MY_OUTFILE} | jq '.tracks.next, .artists.next, .albums.next | strings')
			if [[ -z "${NEXT_URL}" ]]
			then
				echo "No next URL - reached end after ${ITEMS_SO_FAR} out of ${TOTAL_ITEMS} fetched"
				CONTINUE=N
			else
				# jq output has double quotes around it. Need to remove these before using the URL:q
				# echo "${NEXT_URL} is the next URL"
				NEXT_URL=$(removeSurroundingDoubleQuotes ${NEXT_URL})
				# echo "${NEXT_URL} is the next URL"
				ENDPOINT="${NEXT_URL}"

				if (( ITEMS_SO_FAR < MAXITEMS ))
				then
					# Can fetch some more
					:
				else
					echo
					echo "No more results paging: reached max items limit of ${MAXITEMS}"
					CONTINUE=N
				fi
			fi

			rm -f ${MY_OUTFILE}
			rm -f ${MY_HEADER_OUTFILE} 
			rm -f ${MY_REQUEST_OUTFILE}
		else
			echo
			echo "Called curl - failed"
			echo
			RETURN_STATUS=1
			CONTINUE=N
		fi
	done
	return ${RETURN_STATUS}
}


SEARCH_ENDPOINT="v1/search"
SEARCH_DETAIL="q=\"Alison *\"&type=artist"
SEARCH_DETAIL="q=\"Alison *\"&type=artist,album"
SEARCH_DETAIL="q=\"track:Alison *\"&type=track"

SEARCH_DETAIL="q=track:Bewlay&type=track"
SEARCH_DETAIL="q=track:Alison NOT artist:Alison&type=track"
SEARCH_DETAIL="q=track:Alison&type=track"


# List tracks containing the word 'Alison' where one of the artists is called Alison
SEARCH_DETAIL="q=track:Alison artist:Alison&type=track"

SEARCH_DETAIL="q=genre:classical&type=track"	# Returns lots
SEARCH_DETAIL="q=genre:classical tag:new&type=track"	# Returns nothing
SEARCH_DETAIL="q=genre:classical tag:new&type=album"	# Returns nothing
SEARCH_DETAIL="q=genre:classical year:2018&type=album"	# Returns nothing
SEARCH_DETAIL="q=\"Alison Balsom\" year:2015-2016&type=track"

SEARCH_DETAIL="q=track:Bewlay artist:Bowie&type=track"
SEARCH_DETAIL="q=album:\"Hunky *\" artist:Bowie&type=track"

SEARCH_DETAIL="q=Mozart&type=track"
SEARCH_DETAIL="q=Allegretto&type=track"
SEARCH_DETAIL="q=Minuetto%20Allegretto&type=track"

callCurlPaging "GET" "${SEARCH_ENDPOINT}"?"${SEARCH_DETAIL}" "${OUTDIR}/search.json" 200
if [[ $? -ne 0 ]]
then
	echo
	echo "Search failed"
	exit 1
fi

FOUND_ARTISTS=$(cat ${OUTDIR}/search.json | jq '.artists.items[]?.name')
FOUND_ALBUMS=$(cat ${OUTDIR}/search.json | jq '.albums.items[]?.name') 
FOUND_TRACKS=$(cat ${OUTDIR}/search.json | jq '.tracks.items[]?.name')

#More complex output producing JSON snippets including artist and track/album info (NB cross product)
#FOUND_ALBUMS=$(cat ${OUTDIR}/search.json | jq '[.albums.items[]? | {album_name: .name, id: .id, rel_date: .release_date, artist: .artists[]?.name}]') 
#FOUND_TRACKS=$(cat ${OUTDIR}/search.json | jq '[.tracks.items[]? | {track_name: .name, album_name: .album.name, total_artists: .artists | length, artist: .artists[]?.name} ]') 

if isEmptyArrayJQOutput "${FOUND_ARTISTS}"
then
	FOUND_ARTISTS=""
	ARTIST_COUNT=0
else
	declare -i ARTIST_COUNT=$(echo "$FOUND_ARTISTS" | wc -l)
fi

if isEmptyArrayJQOutput "${FOUND_ALBUMS}"
then
	FOUND_ALBUMS=""
	ALBUM_COUNT=0
else
	declare -i ALBUM_COUNT=$(echo "$FOUND_ALBUMS" | wc -l)
fi

if isEmptyArrayJQOutput "${FOUND_TRACKS}"
then
	FOUND_TRACKS=""
	TRACK_COUNT=0
else
	declare -i TRACK_COUNT=$(echo "$FOUND_TRACKS" | wc -l)
fi

LINES_TO_OUTPUT=10
echo "Showing first ${LINES_TO_OUTPUT} lines of results output"
echo
echo "${ARTIST_COUNT} Artists found"
if (( ARTIST_COUNT > 0 ))
then
	echo
	echo "${FOUND_ARTISTS}" | sort | head -${LINES_TO_OUTPUT}
fi
echo
echo "${ALBUM_COUNT} Albums found"
if (( ALBUM_COUNT > 0 ))
then
	echo
	echo "${FOUND_ALBUMS}" | sort | head -${LINES_TO_OUTPUT}
fi
echo
echo "${TRACK_COUNT} Tracks found"
if (( TRACK_COUNT > 0 ))
then
	echo
	echo "${FOUND_TRACKS}" | sort | head -${LINES_TO_OUTPUT}
fi
echo


