#set -x

. ./jqutils.sh
. ./callcurl.sh

OUTDIR="./output/browse"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi


ALBUM_ID1="0cxRAewBpYrtxOYH5fius3"		# Handel's Water Music by Akadamie fur Alte Musik Berlin
ALBUM_ID2="1ay9Z4R5ZYI2TY7WiDhNYQ"		# David Bowie Space Oddity

CATEGORIES_LIST_ENDPOINT="v1/browse/categories?limit=20"
callCurl "GET" "${CATEGORIES_LIST_ENDPOINT}" "${OUTDIR}/categories_list_1_20_example.json"

CATEGORIES_LIST_ENDPOINT="v1/browse/categories?offset=20&limit=20"
callCurl "GET" "${CATEGORIES_LIST_ENDPOINT}" "${OUTDIR}/categories_list_21_40_example.json"

# List out the categories for interest
CATEGORIES=$(cat ${OUTDIR}/categories_list_*_example.json | jq '.categories.items[].name')
echo
echo "Found $(echo \\"$CATEGORIES\\" | wc -l) categories:"
echo
echo "$CATEGORIES"

CATEGORIES_DETAIL_ENDPOINT="v1/browse/categories/metal"
callCurl "GET" "${CATEGORIES_DETAIL_ENDPOINT}" "${OUTDIR}/categories_detail_example.json"

CATEGORIES_PLAYLISTS_ENDPOINT="v1/browse/categories/metal/playlists"
callCurl "GET" "${CATEGORIES_PLAYLISTS_ENDPOINT}" "${OUTDIR}/categories_playlists_example.json"
CATEGORIES_PLAYLIST=$(cat ${OUTDIR}/categories_playlists_example.json | jq '.playlists.items[].name')
echo
echo "Found $(echo \\"$CATEGORIES_PLAYLIST\\" | wc -l) category playlists:"
echo
echo "$CATEGORIES_PLAYLIST"

FEATURED_PLAYLISTS_ENDPOINT="v1/browse/featured-playlists"
callCurl "GET" "${FEATURED_PLAYLISTS_ENDPOINT}" "${OUTDIR}/featured_playlists_example.json"

FEATURED=$(cat ${OUTDIR}/featured_playlists_example.json | jq '.playlists.items[].name')
echo
echo "Found $(echo \\"$FEATURED\\" | wc -l) featured playlists:"
echo
echo "$FEATURED"

NEW_RELEASES_ENDPOINT="v1/browse/new-releases"
callCurl "GET" "${NEW_RELEASES_ENDPOINT}" "${OUTDIR}/new_releases_example.json"

NEW_RELEASES=$(cat ${OUTDIR}/new_releases_example.json | jq '.albums.items[].name')
echo
echo "Found $(echo \\"$NEW_RELEASES\\" | wc -l) new releases:"
echo
echo "$NEW_RELEASES"

echo
echo " .. repeat with paging .. "

callCurlPaging "GET" "${NEW_RELEASES_ENDPOINT}"? "${OUTDIR}/new_releases_paged.json" 800
if [[ $? -ne 0 ]]
then
	echo
	echo "Search failed"
exit 1
else
	echo
	echo "... searching completed"
fi

ITEMS_TO_DISPLAY=60
echo
echo "Showing names of first ${ITEMS_TO_DISPLAY} items of results output (sorted by name):"

for ITEM_TYPE in albums 
do
	FOUND_ITEMS=$(cat ${OUTDIR}/new_releases_paged.json | jq ".${ITEM_TYPE}.items[]?.name")
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

RECOMMENDATIONS_AVAILABLE_SEEDS_ENDPOINT="v1/recommendations/available-genre-seeds"
callCurl "GET" "${RECOMMENDATIONS_AVAILABLE_SEEDS_ENDPOINT}" "${OUTDIR}/recommendations_available_seeds_example.json"

RECOMMENDATIONS_ENDPOINT="v1/recommendations?seed_genres=metal&max_duration_ms=300000"
callCurl "GET" "${RECOMMENDATIONS_ENDPOINT}" "${OUTDIR}/recommendations_example.json"

RECOMMENDATIONS=$(cat ${OUTDIR}/recommendations_example.json | jq '[.tracks[] | {track_name: .name, album_name: .album.name, artist:.artists[0].name}]') 
echo
echo "Found $(echo \\"$RECOMMENDATIONS\\" | grep track_name | wc -l) recommendations:"
echo
echo "$RECOMMENDATIONS"




