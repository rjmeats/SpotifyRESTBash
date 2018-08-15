#set -x

. ./callcurl.sh

OUTDIR="./output/playlists"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

# Public Spotify playlists
PLAYLIST_ID1="37i9dQZF1DWTcqUzwhNmKv"		# Kickass Metal
PLAYLIST_ID2="37i9dQZF1DX6T5dWVv97mp"		# Productive Morning

PLAYLISTS_ENDPOINT="v1/playlists/${PLAYLIST_ID1}"
callCurl "GET" "${PLAYLISTS_ENDPOINT}" "${OUTDIR}/playlists_example.json"

# Multiple playlist request passes in an 'ids' parameter, with comma-separated ID values
# Not a supported option for playlists - returns 'not found'
#ID_PARAM="${PLAYLIST_ID1},${PLAYLIST_ID2}"
#PROTECTED_ID_PARAM=$(protectURLParameter "${ID_PARAM}")
#MULTIPLE_PLAYLISTS_ENDPOINT="v1/playlists?ids=${PROTECTED_ID_PARAM}"
#callCurl "GET" "${MULTIPLE_PLAYLISTS_ENDPOINT}" "${OUTDIR}/multiple_playlists_example.json"

PLAYLIST_TRACKS_ENDPOINT="v1/playlists/${PLAYLIST_ID1}/tracks"
callCurl "GET" "${PLAYLIST_TRACKS_ENDPOINT}" "${OUTDIR}/playlist_tracks_example.json"

PLAYLIST_IMAGES_ENDPOINT="v1/playlists/${PLAYLIST_ID1}/images"
callCurl "GET" "${PLAYLIST_IMAGES_ENDPOINT}" "${OUTDIR}/playlist_images_example.json"

