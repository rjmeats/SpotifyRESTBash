#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/playlists_read"
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

USER_PLAYLISTS_ENDPOINT="v1/users/${USER_ID}/playlists"
callCurl "GET" "${USER_PLAYLISTS_ENDPOINT}" "${OUTDIR}/user_playlists_example.json"

if [[ $? -ne 0 ]]
then
	exit 1
fi

showItemNames "${OUTDIR}/user_playlists_example.json" . 20

echo

cat "${OUTDIR}/user_playlists_example.json" | jq '.items[] | {playlist_id: .id, playlist_name: .name, snapshot_id: .snapshot_id, owner_name: .owner.display_name, public: .public, track_count: .tracks.total}'

ME_PLAYLISTS_ENDPOINT="v1/me/playlists"
callCurl "GET" "${ME_PLAYLISTS_ENDPOINT}" "${OUTDIR}/me_playlists_example.json"

if [[ $? -ne 0 ]]
then
	exit 1
fi

showItemNames "${OUTDIR}/me_playlists_example.json" . 20

# Try to output as name : ID on a single line

echo
cat "${OUTDIR}/user_playlists_example.json" | jq -r '.items[] | .id + " - " + .name' 


