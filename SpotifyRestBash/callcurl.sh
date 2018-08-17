#set -x

. ./jqutils.sh

# ##############################################################################################################
# ##############################################################################################################

# Some common preparatory handling of output files
# Output files involved are:
# - the 'main' output file, used to record the json passed back from the Spotify API responses. 
#   - full filepath stored in $OUTFILE
#   - assumed to end .json
# - the 'headers' file which holds the HTTP headers for the json response 
#   - full filepath stored in $HEADER_OUTFILE
#   - filename created by changing .json to .headers.txt
# - the 'request' file which records the URL+parameters used to make the Spotify API request
#   - full filepath stored in $REQUEST_OUTFILE
#   - filename created by changing .json to .request.txt
#
# Activities are:
# - remove pre-existing files with these names
#   - also remove filenames derived from these by adding a further .xxx suffix - as used when 'paging' through the multiple
#     responses needed to fulfill a search request
# - setting up values in the environment variables

function outputFilePreparation() {

	OUTFILE="$1"
	HEADER_OUTFILE="${OUTFILE//'.json'/'.headers.txt'}"
	REQUEST_OUTFILE="${OUTFILE//'.json'/'.request.txt'}"

	rm -f "${OUTFILE}"
	rm -f "${OUTFILE}.*"
	rm -f "${HEADER_OUTFILE}"
	rm -f "${HEADER_OUTFILE}.*"
	rm -f "${REQUEST_OUTFILE}"
	rm -f "${REQUEST_OUTFILE}.*"
}

# ##############################################################################################################
# ##############################################################################################################

# Invoke curl for a specific verb/entrypoint combination. Record response in the specified output file.

# Simpler form for when there is no data to pass in the request, other than in URL parameters
function callCurl() {
	callCurlFull "$1" "$2" "-" "$3" "$4"
}

function callCurlFull() {

	local VERB="$1"
	local ENDPOINT="$2"
	local REQUEST_DATA="$3"				# Expected to be in json format. If it starts @ then it is a file name
	local OUTFILE_PARAM="$4"			# Expected to end .json and include path info
	local QUIETMODE="${5:-N}"			# Suppress some output e.g. if called within a paging operation

	local URL_BASE="https://api.spotify.com"
	local TOKEN=$(cat token.txt)			# Needs to be updated when the previous token expires or has insufficient access

	local RETURN_STATUS=0

	outputFilePreparation "${OUTFILE_PARAM}"

	# Check whether we need to add the URL_BASE value to the URL (if this is a relative URL) 
	if [[ "${ENDPOINT}" == "${URL_BASE}"* ]]	# Pattern match
	then
		FULL_URL="${ENDPOINT}"
	else
		FULL_URL="${URL_BASE}/${ENDPOINT}"
	fi

	SUMMARY="${VERB} request to ${FULL_URL}"

	if [[ "$REQUEST_DATA" != "-" ]]
	then
		printf -v SUMMARY "%s\r\nRequest Data:\r\n%s" "${SUMMARY}" "$(echo ${REQUEST_DATA} | jq '.')"	# Pipe request into jq to get prettier output
	fi

	if [[ ${QUIETMODE} == "Y" ]]
	then
		echo "${SUMMARY}" > "${REQUEST_OUTFILE}"
	else
		echo
		echo "----------------------------------------------------------------------------------------------------"
		echo
		echo "${SUMMARY}" | tee "${REQUEST_OUTFILE}"
	fi
	{
		# -i displays returned headers. -s is silent mode. -D puts headers into a separate file
		REQ=""
		if [[ "$REQUEST_DATA" == "-" ]]
		then
			curl -s -X "${VERB}" "${FULL_URL}" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -D "${HEADER_OUTFILE}"
		else
			REQ="-d ${REQUEST_DATA}"
			curl -s -X "${VERB}" "${FULL_URL}" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -D "${HEADER_OUTFILE}" "${REQ}" 
		fi

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
		# If the HTTP headers reference HTML, then we've probably got the Spotify API returning an HTML error page.
		if grep -q -i "text/html" "${HEADER_OUTFILE}"
		then
			echo
			echo "*****************************************"
			echo "content type html returned - an error ?"
			mv ${OUTFILE} ${OUTFILE}.html
			echo "renamed output file as .html"
			echo "*****************************************"
			echo
		fi

		# Also check for a 'not found' 404 response in the header file.
		if grep -i "HTTP" "${HEADER_OUTFILE}" | grep -q -i "404"
		then
			echo
			echo "***********************************************"
			echo "HTTP 404 not found reported in response headers"
			echo "***********************************************"
			echo
			RETURN_STATUS=1
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

		# See whether the output json was an error message, in which case we expect an "error" field to be present
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

# Utility to protect (encode) special characters in a URL parameter (e.g. comma, quotes)
# Use jq's @uri method and raw input/output options to do this.

function protectURLParameter () {
	local RAW_PARAM="$1"
	local PROTECTED_PARAM=$(echo -n "${RAW_PARAM}" | jq -sRr '@uri')
	echo ${PROTECTED_PARAM}
}

# ##############################################################################################################
# ##############################################################################################################

# Page through a set of API responses, using Spotify's 'next' URL to fetch subsequent pages, until we reach the end or
# hit a specified maximum. Glue the output files produced by each paging step into one overall file.

function callCurlPaging() {

	local VERB="$1"
	local ENDPOINT="$2"
	local OUTFILE_PARAM="$3"			# Expected to end .json and include path info
	declare -i MAXITEMS=${4:-100}			# Default to returning a maximum of 100 items
	local BATCHSIZE=50				# Max allowed by the Spotify API is 50 per page

	local SUMMARY="${VERB} paging request to ${ENDPOINT}"

	echo
	echo "----------------------------------------------------------------------------------------------------"
	echo
	echo "${SUMMARY}"
	echo

	if (( ${BATCHSIZE} > MAXITEMS ))
	then
		BATCHSIZE="${MAXITEMS}"
	fi

	# Add the batchsize parameter to the URL endpoint.
	# May need to add a '?' if this is the first parameter (i.e. no '?' already present)
	if [[ "${ENDPOINT}" != *\?* ]]
	then
		ENDPOINT="${ENDPOINT}?"
	fi

	ENDPOINT="${ENDPOINT}&limit=${BATCHSIZE}"

	# We're going to use intermediate files with a modified name for each paging step, appending the output
	# into these final files cover the full set of pagings.
	outputFilePreparation "${OUTFILE_PARAM}"
	local FINAL_OUTFILE="${OUTFILE}"
	local FINAL_HEADER_OUTFILE="${HEADER_OUTFILE}"
	local FINAL_REQUEST_OUTFILE="${REQUEST_OUTFILE}"

	declare -i CALL_COUNT=0
	local RETURN_STATUS=0
	# Do initial search call, which can return multiple item lists in combined json response (e.g. for search can hold albums, tracks, artists separately).
	# Then for each item type, do a separate check for 'next' processing in turn.

	let CALL_COUNT+=1
	local MY_OUTFILE=${FINAL_OUTFILE}.${CALL_COUNT}

	callCurl "${VERB}" "${ENDPOINT}" "${MY_OUTFILE}" Y

	if [[ $? -eq 0 ]]
	then
		# Initial call to CURL succeeded

		# Append file output
		local INITIAL_OUTFILE="${OUTFILE}"
		cat ${OUTFILE} | unix2dos >> $FINAL_OUTFILE
		cat ${HEADER_OUTFILE} | unix2dos >> $FINAL_HEADER_OUTFILE
		cat ${REQUEST_OUTFILE} | unix2dos >> $FINAL_REQUEST_OUTFILE

		# Process each known item type in turn
		for ITEM_TYPE in tracks artists albums playlists categories '.'
		do
			if [[ $ITEM_TYPE == "categories" ]]
			then
				ITEM_TYPE_SINGULAR="category"
			elif [[ $ITEM_TYPE == '.' ]]
			then
				ITEM_TYPE_SINGULAR=item
			else
				ITEM_TYPE_SINGULAR=${ITEM_TYPE%s}
			fi

			local CONTINUE=Y
			MY_OUTFILE="${INITIAL_OUTFILE}"
			declare -i ITEMS_SO_FAR=0
			declare -i ITEMS_RETURNED=0
			declare -i TOTAL_ITEMS=0
			local NEXT_URL=""

			while [[ ${CONTINUE} == "Y" ]]
			do
				# Process results from previous call
				if [[ $ITEM_TYPE != '.' ]]
				then
					ITEMS_RETURNED=$(cat ${MY_OUTFILE} | jq ".${ITEM_TYPE}.items | arrays | length")
					TOTAL_ITEMS=$(cat ${MY_OUTFILE} | jq ".${ITEM_TYPE}.total? | numbers")
				else
					ITEMS_RETURNED=$(cat ${MY_OUTFILE} | jq ".items | arrays | length")
					TOTAL_ITEMS=$(cat ${MY_OUTFILE} | jq ".total? | numbers")
				fi
				let ITEMS_SO_FAR+=${ITEMS_RETURNED}

				STOPPING_AFTER_TEXT=""
				if (( TOTAL_ITEMS > MAXITEMS ))
				then
					STOPPING_AFTER_TEXT=", stopping after ${MAXITEMS}"
				fi
					
				if (( ITEMS_RETURNED > 0 ))
				then
					echo "Call ${CALL_COUNT}: retrieved ${ITEMS_RETURNED} ${ITEM_TYPE_SINGULAR} items, ${ITEMS_SO_FAR} items so far out of ${TOTAL_ITEMS}${STOPPING_AFTER_TEXT}"
				fi

				if [[ $ITEM_TYPE != '.' ]]
				then
					NEXT_URL=$(cat ${MY_OUTFILE} | jq ".${ITEM_TYPE}.next | strings")
				else
					NEXT_URL=$(cat ${MY_OUTFILE} | jq ".next | strings")
				fi

				if [[ -z "${NEXT_URL}" ]]
				then
					if (( TOTAL_ITEMS > 0 ))
					then
						echo "Reached end of ${ITEM_TYPE_SINGULAR} results after ${ITEMS_SO_FAR} out of ${TOTAL_ITEMS} fetched"
					fi
					CONTINUE=N
				else
					# jq output has double quotes around it. Need to remove these before using the URL:q
					# echo "${NEXT_URL} is the next URL"
					NEXT_URL=$(removeSurroundingDoubleQuotes ${NEXT_URL})
					# echo "${NEXT_URL} is the next URL"

					if (( ITEMS_SO_FAR < MAXITEMS ))
					then
						:
					else
						echo "No more ${ITEM_TYPE_SINGULAR} results paging: reached max items limit of ${MAXITEMS}"
						CONTINUE=N
					fi
				fi
				
				if [[ "${OUTFILE}" != "${INITIAL_OUTFILE}" ]]
				then
					rm -f ${OUTFILE}
					rm -f ${HEADER_OUTFILE} 
					rm -f ${REQUEST_OUTFILE}i
				fi

				if [[ $CONTINUE == "Y" ]]
				then
					# Fetch some more
					let CALL_COUNT+=1
					local MY_OUTFILE=${FINAL_OUTFILE}.${CALL_COUNT}
					callCurl "${VERB}" "${NEXT_URL}" "${MY_OUTFILE}" Y
					
					if [[ $? -eq 0 ]]
					then
						cat ${OUTFILE} | unix2dos >> $FINAL_OUTFILE
						cat ${HEADER_OUTFILE} | unix2dos >> $FINAL_HEADER_OUTFILE
						echo "Next page : " >> $FINAL_REQUEST_OUTFILE
						cat ${REQUEST_OUTFILE} | unix2dos >> $FINAL_REQUEST_OUTFILE
					else
						echo
						echo "Called curl - failed"
						echo
						RETURN_STATUS=1
						CONTINUE=N
					fi
				fi

			done

		done
	else
		echo
		echo "Called curl - failed"
		echo
		RETURN_STATUS=1
	fi

	return ${RETURN_STATUS}
}

