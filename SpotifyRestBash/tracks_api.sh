#set -x

. ./callcurl.sh

OUTDIR="./output/tracks"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

TRACK_ID1="6H8kRwXYJhmz6y1AkbCwvD"		# Handel's Water Music Suite I  No II Adagio
TRACK_ID2="75c4IPY2EoAyfWuB12VNOa"		# David Bowie's Space Oddity, Wild-eyed boy from Freecloud

TRACKS_ENDPOINT="v1/tracks/${TRACK_ID1}"
callCurl "GET" "${TRACKS_ENDPOINT}" "${OUTDIR}/tracks_example.json"

# Multiple track request passes in an 'ids' parameter, with comma-separated ID values
ID_PARAM="${TRACK_ID1},${TRACK_ID2}"
PROTECTED_ID_PARAM=$(protectURLParameter "${ID_PARAM}")
MULTIPLE_TRACKS_ENDPOINT="v1/tracks?ids=${PROTECTED_ID_PARAM}"
callCurl "GET" "${MULTIPLE_TRACKS_ENDPOINT}" "${OUTDIR}/multiple_tracks_example.json"

AUDIO_ANALYSIS_ENDPOINT="v1/audio-analysis/${TRACK_ID1}"
callCurl "GET" "${AUDIO_ANALYSIS_ENDPOINT}" "${OUTDIR}/tracks_audio_analysis_example.json"

AUDIO_FEATURES_ENDPOINT="v1/audio-features/${TRACK_ID1}"
callCurl "GET" "${AUDIO_FEATURES_ENDPOINT}" "${OUTDIR}/tracks_audio_features_example.json"

# Multiple audio features request passes in an 'ids' parameter, with comma-separated ID values
MULTIPLE_AUDIO_FEATURES_ENDPOINT="v1/audio-features?ids=${PROTECTED_ID_PARAM}"
callCurl "GET" "${MULTIPLE_AUDIO_FEATURES_ENDPOINT}" "${OUTDIR}/multiple_tracks_audio_features_example.json"

