#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/playlists_write"
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

# Try to create a new playlist

CREATE_PLAYLISTS_ENDPOINT="v1/users/${USER_ID}/playlists"
PLAYLIST_NAME="From API $(date)"
PLAYLIST_DESC="New playlist via API"
PLAYLIST_REQUEST="\
{								\
	\"name\": 		\"${PLAYLIST_NAME}\",		\
	\"description\": 	\"${PLAYLIST_DESC}\",		\
	\"public\": 		false				\
}								\
"

callCurlFull "POST" "${CREATE_PLAYLISTS_ENDPOINT}" "${PLAYLIST_REQUEST}" "${OUTDIR}/create_playlist.json"

if [[ $? -eq 0 ]]
then
	# Expect HTTP 200 or 201 response if successful
	if ! grep HTTP "${HEADER_OUTFILE}" | grep -q 20[01]
	then
		echo 
		echo "Playlist creation header response value not expected:"
		echo
		cat "${HEADER_OUTFILE}"
		echo
		exit
	fi

	echo
	echo "Details of new playlist:"
	echo
	cat "${OUTDIR}/create_playlist.json" | jq '{playlist_id: .id, playlist_name: .name, snapshot_id: .snapshot_id, owner_name: .owner.display_name}'
	echo
	NEW_PLAYLIST_ID=$(cat "${OUTDIR}/create_playlist.json" | jq '.id')
	NEW_PLAYLIST_ID=$(removeSurroundingDoubleQuotes ${NEW_PLAYLIST_ID})
	echo "New playlist ID is ${NEW_PLAYLIST_ID}"
else
	echo 
	echo "Failed to create new playlist"
	exit 1
fi

# Try to add a couple of tracks to the new playlist

TRACK_ID1="6H8kRwXYJhmz6y1AkbCwvD"		# Handel's Water Music Suite I  No II Adagio
TRACK_ID2="75c4IPY2EoAyfWuB12VNOa"		# David Bowie's Space Oddity, Wild-eyed boy from Freecloud
TRACK_ID3="4GRDiNU8fkizXz4rDX9gS5"		# David Bowie's Space Oddity, Wild-eyed boy from Freecloud

ADD_TRACKS_ENDPOINT="v1/playlists/${NEW_PLAYLIST_ID}/tracks"
ADD_TRACKS_REQUEST="\
{								\
	\"uris\": [						\
		\"spotify:track:${TRACK_ID1}\",			\
		\"spotify:track:${TRACK_ID2}\",			\
		\"spotify:track:${TRACK_ID3}\"			\
	]							\
}								\
"

callCurlFull "POST" "${ADD_TRACKS_ENDPOINT}" "${ADD_TRACKS_REQUEST}" "${OUTDIR}/add_tracks.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Added tracks to new playlist"
	cat ${OUTDIR}/add_tracks.json
	echo
else
	echo
	echo "Failed to add tracks to new playlist"
	exit 1
fi

#############################################################################

# Try to swap the playlist track order using the 'reorder' API

REORDER_PLAYLIST_ENDPOINT="v1/playlists/${NEW_PLAYLIST_ID}/tracks"		# Same as for adding
REORDER_TRACKS_REQUEST="\
{								\
	\"range_start\": 	1,				\
	\"range_length\": 	1,				\
	\"insert_before\": 	0				\
}								\
"

callCurlFull "PUT" "${REORDER_PLAYLIST_ENDPOINT}" "${REORDER_TRACKS_REQUEST}" "${OUTDIR}/reorder_playlist_tracks.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Reordered tracks in new playlist"
	cat ${OUTDIR}/reorder_playlist_tracks.json
	echo
else
	echo
	echo "Failed to reorder tracks in new playlist"
	exit 1
fi


#############################################################################

# Try to delete a track from a playlist 

DELETE_PLAYLIST_TRACKS_ENDPOINT="v1/playlists/${NEW_PLAYLIST_ID}/tracks"		# Same as for adding tracks
DELETE_TRACKS_REQUEST="\
{								\
	\"uris\": [						\
		\"spotify:track:${TRACK_ID2}\"			\
	]							\
}								\
"

callCurlFull "DELETE" "${DELETE_PLAYLIST_TRACKS_ENDPOINT}" "${DELETE_TRACKS_REQUEST}" "${OUTDIR}/delete_playlist_tracks.json"

if [[ $? -eq 0 ]]
then
	echo
	echo "Deleted track in new playlist"
	cat ${OUTDIR}/delete_playlist_tracks.json
	echo
else
	echo
	echo "Failed to delete track in new playlist"
	exit 1
fi



