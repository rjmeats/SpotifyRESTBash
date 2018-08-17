#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/personalization"
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


MY_TOP_ARTISTS_ENDPOINT="v1/me/top/artists"	

callCurlPaging "GET" "${MY_TOP_ARTISTS_ENDPOINT}" "${OUTDIR}/my_top_artists.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Extracted my top artists:"
	echo
else
	echo
	echo "Failed to extract my top artists"
	exit 1
fi

showItemNames ${OUTDIR}/my_top_artists.json . 60 

########################################################################################

MY_TOP_TRACKS_ENDPOINT="v1/me/top/tracks"	

callCurlPaging "GET" "${MY_TOP_TRACKS_ENDPOINT}" "${OUTDIR}/my_top_tracks.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Extracted my top tracks:"
	echo
else
	echo
	echo "Failed to extract my top tracks"
	exit 1
fi

showItemNames ${OUTDIR}/my_top_tracks.json . 60 
