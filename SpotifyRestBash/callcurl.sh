#set -x

. ./jqutils.sh

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

		if grep -q -i "\"error\"" ${OUTFILE} 
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

# Page through a set of API responses, using Spotify's 'next' URL to fetch subsequent pages, until we reach the end or
# hit a specified maximum. Glue the output files produced into one big file.
function callCurlPaging() {

	local VERB="$1"
	local ENDPOINT="$2"
	local OUTFILE="$3"			# Expected to end .json and include path info

	declare -i MAXITEMS=${4:-100}		# Default to 100 items
	local BATCHSIZE=50			# Max allowed by API is 50

	ENDPOINT="${ENDPOINT}&limit=${BATCHSIZE}"

	if [[ -f ${OUTFILE} ]]
	then
		rm ${OUTFILE} 
	fi

	if [[ -f ${OUTFILE}.html ]]
	then
		rm ${OUTFILE}.html 
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

	local CONTINUE=Y
	declare -i ITEMS_SO_FAR=0
	declare -i ITEMS_RETURNED=0
	declare -i TOTAL_ITEMS=0
	declare -i CALL_COUNT=0
	local NEXT_URL=""

	local RETURN_STATUS=0

	while [[ ${CONTINUE} == "Y" ]]
	do
		let CALL_COUNT+=1
		local MY_OUTFILE=${OUTFILE}.${CALL_COUNT}
		local MY_HEADER_OUTFILE=${HEADER_OUTFILE}.${CALL_COUNT}
		local MY_REQUEST_OUTFILE=${REQUEST_OUTFILE}.${CALL_COUNT}

		callCurl "${VERB}" "${ENDPOINT}" "${MY_OUTFILE}" Y

		if [[ $? -eq 0 ]]
		then
			# Called Curl OK, 
			# Count items return
			# Expect the results to have only one of tracks, artists or albums, using the 'paging object' Spotify json structure.
			# This is only true if the query only specifies a single type. If multiple types are specified, then there are multiple
			# items arrays, and the code below doesn't work. Note also that there are multiple nexts too. So to handle this properly,
			# would need to look at tracks/artists/albums individually, perhaps as separate loops after the initial search result 
			# has been received, and do next-handling separately for each.
			# How many items in the 'items' array ?
			ITEMS_RETURNED=$(cat ${MY_OUTFILE} | jq ".tracks.items, .artists.items, .albums.items | arrays | length")
			# How many total items found by this search ?
			TOTAL_ITEMS=$(cat ${MY_OUTFILE} | jq ".tracks.total?, .artists.total?, .albums.total? | numbers")
			let ITEMS_SO_FAR+=${ITEMS_RETURNED}
			echo "Call ${CALL_COUNT}: retrieved ${ITEMS_RETURNED} more items, ${ITEMS_SO_FAR} items so far out of ${TOTAL_ITEMS}, stopping after ${MAXITEMS}"

			# Append file output
			cat ${MY_OUTFILE} >> $OUTFILE
			cat ${MY_HEADER_OUTFILE} >> $HEADER_OUTFILE
			cat ${MY_REQUEST_OUTFILE} >> $REQUEST_OUTFILE

			# Extract a next URL. null means we've got everything
			NEXT_URL=$(cat ${MY_OUTFILE} | jq '.tracks.next, .artists.next, .albums.next | strings')
			if [[ -z "${NEXT_URL}" ]]
			then
				echo "Reached end of results after ${ITEMS_SO_FAR} out of ${TOTAL_ITEMS} fetched"
				CONTINUE=N
			else
				# jq output has double quotes around it. Need to remove these before using the URL:q
				# echo "${NEXT_URL} is the next URL"
				NEXT_URL=$(removeSurroundingDoubleQuotes ${NEXT_URL})
				# echo "${NEXT_URL} is the next URL"
				ENDPOINT="${NEXT_URL}"

				if (( ITEMS_SO_FAR < MAXITEMS ))
				then
					# Can fetch some more
					:
				else
					echo
					echo "No more results paging: reached max items limit of ${MAXITEMS}"
					CONTINUE=N
				fi
			fi

			rm -f ${MY_OUTFILE}
			rm -f ${MY_HEADER_OUTFILE} 
			rm -f ${MY_REQUEST_OUTFILE}
		else
			echo
			echo "Called curl - failed"
			echo
			RETURN_STATUS=1
			CONTINUE=N
		fi
	done
	return ${RETURN_STATUS}
}

