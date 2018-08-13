#set -x

. ./callcurl.sh

OUTDIR="./output/albums"
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

ALBUMS_ENDPOINT="v1/albums/${ALBUM_ID1}"
callCurl "GET" "${ALBUMS_ENDPOINT}" "${OUTDIR}/albums_example.json"

ALBUMS_TRACKS_ENDPOINT="v1/albums/${ALBUM_ID1}/tracks"
callCurl "GET" "${ALBUMS_TRACKS_ENDPOINT}" "${OUTDIR}/albums_tracks_example.json"

# Multiple album request passes in an 'ids' parameter, with comma-separated ID values
ID_PARAM="${ALBUM_ID1},${ALBUM_ID2}"
PROTECTED_ID_PARAM=$(protectURLParameter "${ID_PARAM}")
MULTIPLE_ALBUMS_ENDPOINT="v1/albums?ids=${PROTECTED_ID_PARAM}"
callCurl "GET" "${MULTIPLE_ALBUMS_ENDPOINT}" "${OUTDIR}/multiple_albums_example.json"

