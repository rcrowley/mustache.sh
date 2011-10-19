set -e

exec 3>/dev/null

die() {
	echo "mustache.sh: $1" >&2
	exit 1
}

literal() {
	STATE="literal" NEXT_STATE=""
	case "$PREV_CHAR$CHAR" in
		"{{") STATE="tag";;
		*"{") ;;
		*) [ -z "$CHAR" ] && echo >&$FD || printf "%c" "$CHAR" >&$FD;;
	esac
}

STATE="literal" NEXT_STATE="literal" FD=1
sed -r "s/./&\n/g" | while read CHAR
do
	#echo " CHAR: $CHAR (${#CHAR})" | cat -A >&2
	case "$STATE" in
		"literal") literal;;
		"tag")
			case "$PREV_CHAR$CHAR" in
				"{{") printf "{" >&$FD;;
				"{#") NEXT_STATE="#" TAG="";;
				"{^") NEXT_STATE="^" TAG="";;
				"{/") NEXT_STATE="/" TAG="";;
				"{!") NEXT_STATE="!" TAG="";;
				"{>") NEXT_STATE=">" TAG="";;
				"{"*) NEXT_STATE="variable" TAG="$CHAR";;
				"}}") STATE="$NEXT_STATE" NEXT_STATE="";;
				*"}") ;;
				"}"*) TAG="$TAG}";;
				*) TAG="$TAG$CHAR";;
			esac;;
		"variable")
			eval printf "%s" "\$$TAG" >&$FD
			literal;;
		"#")
			SECTION_TAG="$TAG"
			[ -n "$(eval printf "%s" "\$$TAG")" ] && FD=1 || FD=3
			# TODO Make a recursive call.
			literal;;
		"^")
			SECTION_TAG="$TAG"
			[ -z "$(eval printf "%s" "\$$TAG")" ] && FD=1 || FD=3
			# TODO Make a recursive call.
			literal;;
		"/")
			if [ "$TAG" != "$SECTION_TAG" ]
			then
				die "mismatched closing tag $TAG, expected $SECTION_TAG"
			fi
			# TODO Exit the recursive call.
			FD=1
			literal;;
		"!") literal;;
		">") die "{{>$TAG}} syntax not implemented";;
	esac
	PREV_CHAR="$CHAR"
done
