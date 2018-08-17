#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/library"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

USER_ID=$(cat .userid)

########################################################################################

MY_SAVED_ALBUMS_ENDPOINT="v1/me/albums"	

callCurlPaging "GET" "${MY_SAVED_ALBUMS_ENDPOINT}" "${OUTDIR}/my_saved_albums.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Extracted my saved albums:"
	echo
else
	echo
	echo "Failed to extract my saved albums"
	exit 1
fi

showItemNames ${OUTDIR}/my_saved_albums.json . 60 

########################################################################################

MY_SAVED_TRACKS_ENDPOINT="v1/me/tracks"	

callCurlPaging "GET" "${MY_SAVED_TRACKS_ENDPOINT}" "${OUTDIR}/my_saved_tracks.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Extracted my saved tracks:"
	echo
else
	echo
	echo "Failed to extract my saved tracks"
	exit 1
fi

#showItemNames ${OUTDIR}/my_saved_tracks.json . 60 
#Normal showItemNames function doesn't work as paged results have an extra level of nesting, to allow an 'added at' field
#to be returned, as well as the track.
FOUND_ITEMS=$(cat ${OUTDIR}/my_saved_tracks.json | jq ".items[]?.track.name")
echo "${FOUND_ITEMS}"

