#set -x

function callCurl() {

	local VERB="$1"
	local ENDPOINT="$2"
	local OUTFILE="$3"			# Expected to end .json and include path info
	local QUIETMODE="${4:-N}"

	local URL_BASE="https://api.spotify.com"
	local TOKEN=$(cat token.txt)		# Needs to be updated when the previous token expires or has insufficient access

	local RETURN_STATUS=0

	if [[ -f ${OUTFILE} ]]
	then
		rm ${OUTFILE} 
	fi

	if [[ -f ${OUTFILE}.html ]]
	then
		rm ${OUTFILE}.html 
	fi

	local HEADER_OUTFILE="${OUTFILE//'.json'/'.headers.txt'}"
	if [[ -f ${HEADER_OUTFILE} ]]
	then
		rm ${HEADER_OUTFILE} 
	fi

	local REQUEST_OUTFILE="${OUTFILE//'.json'/'.request.txt'}"
	if [[ -f ${REQUEST_OUTFILE} ]]
	then
		rm ${REQUEST_OUTFILE} 
	fi

	# Check whether we need to add the URL_BASE if this is a relative URL
	if [[ "${ENDPOINT}" == "${URL_BASE}"* ]]
	then
		FULL_URL="${ENDPOINT}"
	else
		FULL_URL="${URL_BASE}/${ENDPOINT}"
	fi
	SUMMARY="${VERB} request to ${FULL_URL}"

	if [[ ${QUIETMODE} == "Y" ]]
	then
		echo "${SUMMARY}" > ${REQUEST_OUTFILE}
	else
		echo "----------------------------------------------------------------------------------------------------"
		echo
		echo "${SUMMARY}" | tee ${REQUEST_OUTFILE}
	fi
	{
		# -i displays returned headers. -s is silent mode. -D puts headers into a separate file
		curl -s -X "${VERB}" "${FULL_URL}" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -D "${HEADER_OUTFILE}" 
		CURLSTATUS=$?
	} > ${OUTFILE}

	if [[ ${CURLSTATUS} -ne 0 ]]
	then
		echo
		echo "**********************"
		echo "**** curl status was ${CURLSTATUS}"
		echo "**********************"
		RETURN_STATUS=1
	fi

	if [[ -f ${HEADER_OUTFILE} ]]
	then
		if grep -q -i "text/html" "${HEADER_OUTFILE}"
		then
			echo
			echo "*****************************************"
			echo "content type html returned - an error ?"
			mv ${OUTFILE} ${OUTFILE}.html
			echo "renamed file as .html"
			echo "*****************************************"
			echo
		fi
	fi

	if [[ -f ${OUTFILE} ]]
	then
		if [[ ${QUIETMODE} == "Y" ]]
		then
			:
		else
		echo
			echo "Output is in ${OUTFILE}"
			ls -lt ${OUTFILE} 
		fi

		if grep -q -i error ${OUTFILE} 
		then
			echo
			echo "*****************************************"
			echo "**** error reported in returned json ****"
			echo
			echo "See file ${OUTFILE}"
			echo
			head -10 ${OUTFILE}
			echo
			echo
			echo "*****************************************"
			RETURN_STATUS=1
		fi
	elif [[ -f ${OUTFILE}.html ]]
	then
		echo
		echo "Outfile renamed as ${OUTFILE}.html"
		ls -lt ${OUTFILE}.html
		RETURN_STATUS=1
	else
		echo
		echo "*********************************"
		echo "**** No output file produced ****"
		echo "*********************************"
		RETURN_STATUS=1
	fi

	return ${RETURN_STATUS}
}

# Protect special characters in URL parameter (e.g. comma, quotes)
# Use jq's @uri method and raw input/output options to do this.
function protectURLParameter () {
	local RAW_PARAM="$1"
	local PROTECTED_PARAM=$(echo -n "${RAW_PARAM}" | jq -sRr '@uri')
	echo ${PROTECTED_PARAM}
}

