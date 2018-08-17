#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/playlists_bulk_unfollow"
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


function unfollow() {
	
	PLAYLIST_ID="$1"

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
		echo "Unfollowed playlist ${PLAYLIST_ID}"
		echo
	else
		echo
		echo "Failed to unfollow playlist ${PLAYLIST_ID}"
		exit 1
	fi
}


OUTDIR="./user_output/playlists_read"
cat "${OUTDIR}/user_playlists_example.json" | jq -r '.items[] | .id + " - " + .name' | grep "From API"

for PL in $(cat "${OUTDIR}/user_playlists_example.json" | jq -r '.items[] | .id + " - " + .name' | grep "From API" | cut -f 1 -d" ")
do
	unfollow $PL
done



