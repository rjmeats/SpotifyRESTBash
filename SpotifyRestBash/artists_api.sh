#set -x

. ./callcurl.sh

OUTDIR="./output/artists"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi


ARTIST_ID1="1QL7yTHrdahRMpvNtn6rI2"		# Handel
ARTIST_ID2="0oSGxfWSnnOXhD2fKuz2Gy"		# David Bowie

ARTISTS_ENDPOINT="v1/artists/${ARTIST_ID1}"
callCurl "GET" "${ARTISTS_ENDPOINT}" "${OUTDIR}/artists_example.json"

# Multiple artists request passes in an 'ids' parameter, with comma-separated ID values
MULTIPLE_ARTISTS_ENDPOINT="v1/artists?ids=${ARTIST_ID1},${ARTIST_ID2}"
callCurl "GET" "${MULTIPLE_ARTISTS_ENDPOINT}" "${OUTDIR}/multiple_artists_example.json"


ARTISTS_ALBUMS_ENDPOINT="v1/artists/${ARTIST_ID1}/albums"
callCurl "GET" "${ARTISTS_ALBUMS_ENDPOINT}" "${OUTDIR}/artists_albums_example.json"

# Top-tracks request must have a country parameter
ARTISTS_TOP_TRACKS_ENDPOINT="v1/artists/${ARTIST_ID1}/top-tracks?country=GB"
callCurl "GET" "${ARTISTS_TOP_TRACKS_ENDPOINT}" "${OUTDIR}/artists_top_tracks_example.json"


ARTISTS_RELATED_ARTISTS_ENDPOINT="v1/artists/${ARTIST_ID1}/related-artists"
callCurl "GET" "${ARTISTS_RELATED_ARTISTS_ENDPOINT}" "${OUTDIR}/artists_related_artists_example.json"

