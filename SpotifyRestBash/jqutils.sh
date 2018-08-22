# Generic processing relating to jq 

# jq extracts string fields with their surrounding double quotes, this function removes them.
function removeSurroundingDoubleQuotes() {
	local S_IN="$1"
	local S_OUT="${S_IN%\"}"		# Remove right double quote if present
	S_OUT="${S_OUT#\"}"			# Remove left double quote if present
	echo "${S_OUT}"
}

function removeSurroundingSquareBrackets() {
	local S_IN="$1"
	local S_OUT="${S_IN%\]}"		# Remove right square bracket if present
	S_OUT="${S_OUT#\[}"			# Remove left square bracket if present
	echo "${S_OUT}"
}

# Not sure how to suppress some cases of jq returning json consisting of just empty arrays as []. Strip them out here.
function isEmptyArrayJQOutput() {
	local STRIPPED=$(echo "$1" | tr -d '\[\]\012\015')
	if [[ -z ${STRIPPED} ]]
	then
		return 0
	else
		return 1
	fi
}


