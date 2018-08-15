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

function callCurl() {

	local VERB="$1"
	local ENDPOINT="$2"
	local OUTFILE_PARAM="$3"			# Expected to end .json and include path info
	local QUIETMODE="${4:-N}"			# Suppress some output e.g. if called within a paging operation

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

	if [[ ${QUIETMODE} == "Y" ]]
	then
		echo "${SUMMARY}" > "${REQUEST_OUTFILE}"
	else
		echo "----------------------------------------------------------------------------------------------------"
		echo
		echo "${SUMMARY}" | tee "${REQUEST_OUTFILE}"
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
		local MY_OUTFILE=${FINAL_OUTFILE}.${CALL_COUNT}

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
			ITEMS_RETURNED=$(cat ${MY_OUTFILE} | jq ".tracks.items, .artists.items, .albums.items, .playlists.items, .categories.items | arrays | length")
			# How many total items found by this search ?
			TOTAL_ITEMS=$(cat ${MY_OUTFILE} | jq ".tracks.total?, .artists.total?, .albums.total?, .playlists.total, .categories.total? | numbers")
			let ITEMS_SO_FAR+=${ITEMS_RETURNED}

			STOPPING_AFTER_TEXT=""
			if (( TOTAL_ITEMS > MAXITEMS ))
			then
				STOPPING_AFTER_TEXT=", stopping after ${MAXITEMS}"
			fi
			echo "Call ${CALL_COUNT}: retrieved ${ITEMS_RETURNED} items, ${ITEMS_SO_FAR} items so far out of ${TOTAL_ITEMS}${STOPPING_AFTER_TEXT}"

			# Append file output
			cat ${OUTFILE} | unix2dos >> $FINAL_OUTFILE
			cat ${HEADER_OUTFILE} | unix2dos >> $FINAL_HEADER_OUTFILE
			cat ${REQUEST_OUTFILE} | unix2dos >> $FINAL_REQUEST_OUTFILE

			# Extract a next URL. null means we've got everything
			NEXT_URL=$(cat ${MY_OUTFILE} | jq '.tracks.next, .artists.next, .albums.next, .playlists.next, .categories.next | strings')
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

			rm -f ${OUTFILE}
			rm -f ${HEADER_OUTFILE} 
			rm -f ${REQUEST_OUTFILE}
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

