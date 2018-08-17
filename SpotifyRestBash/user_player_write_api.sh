#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/player_write"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

########################################################################################

# Try to create a new playlist

PAUSE_PLAYER_ENDPOINT="v1/me/player/pause"

callCurlFull "PUT" "${PAUSE_PLAYER_ENDPOINT}" "-" "${OUTDIR}/user_pause_player.json"

if [[ $? -eq 0 ]]
then
	# Returns 403 for non-premium user
	cat "${HEADER_OUTFILE}"
	echo

else
	echo 
	echo "Failed to pause player"
	exit 1
fi

