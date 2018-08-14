#
# Get an authorisation token via the 'Client Credentials Flow' approach described here.
#
# https://developer.spotify.com/documentation/general/guides/authorization-guide
#
# This uses a client ID and secret to generate a token that can be used to access generic Spotify API content, but not
# anything user-related.

. ./jqutils.sh
. ./.id	

function toBase64 () {
	local RAW_PARAM="$1"
	local B64_PARAM=$(echo -n "${RAW_PARAM}" | jq -sRr '@base64')
	echo ${B64_PARAM}
}

# Invoke the spotify authentication endpoint, passing in client info

IDSE64=$(toBase64 "${CLIENT_ID}:${CLIENT_SE}")
TOKEN_RESPONSE=$(curl -s -X "POST" -H "Authorization: Basic ${IDSE64}" -d grant_type=client_credentials https://accounts.spotify.com/api/token)

if [[ $? -ne 0 ]]
then
	echo "Failure requesting obtain token"
	echo
	echo "${TOKEN_RESPONSE}"
	exit 1
fi

if echo "${TOKEN_RESPONSE}" | grep -q -i "\"error\"" 
then
	echo "Token response error:"
	echo
	echo "${TOKEN_RESPONSE}"
	exit 1
fi

# Pull out the token value from the json response, remove surrounding double quotes which jq leaves on.
TOKEN=$(echo "${TOKEN_RESPONSE}" | jq '.access_token')
TOKEN=$(removeSurroundingDoubleQuotes ${TOKEN})

# Put the token in the designated file
echo "${TOKEN}" > ./token.txt
