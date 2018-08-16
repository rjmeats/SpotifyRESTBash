# Common functions used for formatting returned Spotify JSON for display

. ./jqutils.sh

# Spotfiy json often includes .item[] arrays of objects, for a variety of object types, each having a 'name' field
# This function pulls out these item names into a sort list and displays them

function showItemNames() {
	local OUTPUT_FILE="$1"	# Where the json output is held
	local ITEM_TYPE="$2"	# The name of the element which contains the items[] array, e.g. albums, or can be just '.'
	local MAX_ITEMS_TO_DISPLAY="$3"

	local FOUND_ITEMS
	if [[ $ITEM_TYPE != "." ]]
	then
		FOUND_ITEMS=$(cat ${OUTPUT_FILE} | jq ".${ITEM_TYPE}.items[]?.name")
	else
		# Top level item
		FOUND_ITEMS=$(cat ${OUTPUT_FILE} | jq ".items[]?.name")
	fi

	declare -i FOUND_ITEM_COUNT

	if isEmptyArrayJQOutput "${FOUND_ITEMS}"
	then
		FOUND_ITEMS=""
		FOUND_ITEM_COUNT=0
	else
		FOUND_ITEM_COUNT=$(echo "$FOUND_ITEMS" | wc -l)
	fi
	
	# Change the top-level item type indicator from '.'  to 'items' for producing output text
	if [[ $ITEM_TYPE == "." ]]
	then
		ITEM_TYPE="items"
	fi

	# Spotify uses plural attribute names for its objects. Produce a singular form too, by removing the final
	# 's' unless it's a known special case.
	ITEM_TYPE_SINGULAR=${ITEM_TYPE%s}
	if [[ $ITEM_TYPE_SINGULAR == "categorie" ]]
	then
		ITEM_TYPE_SINGULAR="category"
	fi	

	echo
	if (( FOUND_ITEM_COUNT == 1 ))
	then
		echo "${FOUND_ITEM_COUNT} ${ITEM_TYPE_SINGULAR} found"
	else
		echo "${FOUND_ITEM_COUNT} ${ITEM_TYPE} found"
	fi
	
	if (( FOUND_ITEM_COUNT > 0 ))
	then
		local VTEXT=""
		if (( FOUND_ITEM_COUNT > MAX_ITEMS_TO_DISPLAY ))
		then
			VTEXT="the first ${MAX_ITEMS_TO_DISPLAY}"
		else
			VTEXT="all ${FOUND_ITEM_COUNT}"
		fi
		echo
		echo "Showing ${VTEXT} ${ITEM_TYPE_SINGULAR} names from results output (sorted by name):"
		echo
		echo "${FOUND_ITEMS}" | sort | head -${MAX_ITEMS_TO_DISPLAY}
	fi
}
