#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/playlists_follow"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

# Show Spotify playlists - NB need to use a token with approproiate scopes to see them, especially private ones.

USER_ID=$(cat .userid)

########################################################################################

# Try to follow a playlist 

PLAYLIST_ID="1p8u1qNJJTwDmJfMSa0Vws"

FOLLOW_PLAYLISTS_ENDPOINT="v1/playlists/${PLAYLIST_ID}/followers"	

callCurlFull "PUT" "${FOLLOW_PLAYLISTS_ENDPOINT}" "-" "${OUTDIR}/follow_playlist.json"

if [[ $? -eq 0 ]]
then
	# Expect HTTP 200 response if successful
	if ! grep HTTP "${HEADER_OUTFILE}" | grep -q 200
	then
		echo 
		echo "Playlist follow response value not expected:"
		echo
		cat "${HEADER_OUTFILE}"
		echo
		exit
	fi

	echo
	echo "Followed playlist"
	echo
else
	echo
	echo "Failed to follow playlist"
	exit 1
fi

########################################################################################

# Try to unfollow the playlist 

UNFOLLOW_PLAYLISTS_ENDPOINT="v1/playlists/${PLAYLIST_ID}/followers"		# Same as for following

callCurlFull "DELETE" "${UNFOLLOW_PLAYLISTS_ENDPOINT}" "-" "${OUTDIR}/unfollow_playlist.json"

if [[ $? -eq 0 ]]
then
	# Expect HTTP 200 response if successful
	if ! grep HTTP "${HEADER_OUTFILE}" | grep -q 200
	then
		echo 
		echo "Playlist unfollow response value not expected:"
		echo
		cat "${HEADER_OUTFILE}"
		echo
		exit
	fi

	echo
	echo "Unfollowed playlist"
	echo
else
	echo
	echo "Failed to unfollow playlist"
	exit 1
fi


