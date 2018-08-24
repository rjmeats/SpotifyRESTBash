#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/recent"
if [[ ! -d ${OUTDIR} ]]
then
	mkdir ${OUTDIR}
	if [[ $? -ne 0 ]]
	then
		echo "**** Failed to create output directory ${OUTDIR} ****"
		exit 1
	fi
fi

######################################################################################

# Show recently played
# Request 100 but the API only returns 50 (regardless of batch size/next processing)

RECENTLY_PLAYED_ENDPOINT="v1/me/player/recently-played"
callCurlPaging "GET" "${RECENTLY_PLAYED_ENDPOINT}" "${OUTDIR}/recent.json" 100

if [[ $? -ne 0 ]]
then
	echo "Get recently-played call failed"
	exit 1
elif [[ ${CURL_HTTP_RESPONSE} -ne 200 ]]
then
	echo "Unexpected HTTP Response: ${CURL_HTTP_RESPONSE}"
	exit 1
else
	echo
	echo "Recently played tracks:"
	echo
	RECENT=$(cat ${OUTDIR}/recent.json | jq -r '.items[] | .played_at+" - "+.context.type+" - "+.track.name')
	echo "${RECENT}"
fi

