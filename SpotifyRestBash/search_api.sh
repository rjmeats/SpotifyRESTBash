#set -x

. ./jqutils.sh
. ./callcurl.sh

# Format a search query and summarise the output
function doSearch() {

	local QUERY="$1"
	local TYPE="$2"
	local MAX_ITEMS="${3:-100}"

	local PROTECTED_QUERY=$(protectURLParameter "${QUERY}")
	local PROTECTED_TYPE=$(protectURLParameter "${TYPE}")
	local SEARCH_ENDPOINT="v1/search"
	local SEARCH_PARAMS="q=${PROTECTED_QUERY}&type=${PROTECTED_TYPE}"

	echo
	echo "Doing search for '${QUERY}' and type '${TYPE}' ..."
	echo

	callCurlPaging "GET" "${SEARCH_ENDPOINT}"?"${SEARCH_PARAMS}" "${OUTDIR}/search.json" ${MAX_ITEMS}
	if [[ $? -ne 0 ]]
	then
		echo
		echo "Search failed"
		exit 1
	else
		echo
		echo "... searching completed"
	fi

	local ITEMS_TO_DISPLAY=100
	echo
	echo "Showing names of first ${ITEMS_TO_DISPLAY} items of results output (sorted by name):"

	for ITEM_TYPE in artists albums tracks
	do
		local FOUND_ITEMS=$(cat ${OUTDIR}/search.json | jq ".${ITEM_TYPE}.items[]?.name")
		declare -i FOUND_ITEM_COUNT
		
		if isEmptyArrayJQOutput "${FOUND_ITEMS}"
		then
			FOUND_ITEMS=""
			FOUND_ITEM_COUNT=0
		else
			FOUND_ITEM_COUNT=$(echo "$FOUND_ITEMS" | wc -l)
		fi

		echo
		echo "${FOUND_ITEM_COUNT} ${ITEM_TYPE} found"
		if (( FOUND_ITEM_COUNT > 0 ))
		then
			echo
			echo "${FOUND_ITEMS}" | sort | head -${ITEMS_TO_DISPLAY}
		fi
	done
}

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

# doSearch "track:\"Alison *\" NOT track:\"Alison Gross\"" "track"
#doSearch "track:\"* Alison *\" NOT track:\"Alison Gross\"" "track"
doSearch "Beethoven Moonlight" "album" 500
#doSearch "artist:Beethoven" "artist"

