#set -x

. ./callcurl.sh
. ./formatutils.sh

OUTDIR="./user_output/user_read"
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

# Show user

USER_ENDPOINT="v1/me"
callCurl "GET" "${USER_ENDPOINT}" "${OUTDIR}/user.json"

if [[ $? -ne 0 ]]
then
	echo "Get user call failed"
else
	echo
	cat ${OUTDIR}/user.json

fi

