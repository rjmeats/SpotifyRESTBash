#set -x

function callCurl() {

	local VERB="$1"
	local ENDPOINT="$2"
	ENDPOINT="${ENDPOINT//','/%2C}"		# Protect commas in URLs
	local OUTFILE="$3"			# Expected to end .json and include path info

	local URL_BASE="https://api.spotify.com"
	local TOKEN=$(cat token.txt)		# Needs to be updated when the previous token expires or has insufficient access

	if [[ -f ${OUTFILE} ]]
	then
		rm ${OUTFILE} 
	fi

	HEADER_OUTFILE="${OUTFILE//'.json'/'.headers.txt'}"
	if [[ -f ${HEADER_OUTFILE} ]]
	then
		rm ${HEADER_OUTFILE} 
	fi

	REQUEST_OUTFILE="${OUTFILE//'.json'/'.request.txt'}"
	if [[ -f ${REQUEST_OUTFILE} ]]
	then
		rm ${REQUEST_OUTFILE} 
	fi

	SUMMARY="${VERB} request to ${URL_BASE}/${ENDPOINT}"
	echo "----------------------------------------------------------------------------------------------------"
	echo
	echo "${SUMMARY}" | tee ${REQUEST_OUTFILE}
	{
		# -i displays returned headers. -s is silent mode. -D puts headers into a separate file
		curl -s -X "${VERB}" "${URL_BASE}/${ENDPOINT}" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -D "${HEADER_OUTFILE}" 
		CURLSTATUS=$?
	} > ${OUTFILE}

	if [[ ${CURLSTATUS} -ne 0 ]]
	then
		echo
		echo "**********************"
		echo "**** curl status was ${CURLSTATUS}"
		echo "**********************"
		sleep 1
	fi

	if [[ -f ${OUTFILE} ]]
	then
		echo
		echo "Output is in ${OUTFILE}"
		ls -lt ${OUTFILE} 

		if grep -q -i error ${OUTFILE} 
		then
			echo
			echo "*****************************************"
			echo "**** error reported in returned json ****"
			head -10 ${OUTFILE}
			echo "*****************************************"
			sleep 1
		fi
	else
		echo
		echo "*********************************"
		echo "**** No output file produced ****"
		echo "*********************************"
		sleep 1
	fi

	sleep 1
}


