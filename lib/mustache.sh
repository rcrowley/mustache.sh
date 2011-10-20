# `mustache.sh`, Mustache in POSIX shell.

set -e

# File descriptor 3 is commandeered for use as a sink for literal and
# variable output of (inverted) sections that are not destined for standard
# output because their condition is not met.
exec 3>/dev/null

# Print an error message and GTFO.
mustache_die() {
	echo "mustache.sh: $@" >&2
	exit 1
}

# Consume a single character literal.  In the event this character and the
# previous character have been opening braces, progress to the tag state.
# If this is the first opening brace, wait and see.  Otherwise, emit this
# character literal.
mustache_literal() {
	_M_STATE="literal" _M_NEXT_STATE=""
	case "$_M_PREV_C$_M_C" in
		"{{") _M_STATE="tag";;
		*"{") ;;
		*)
			if [ -z "$_M_C" ]
			then
				echo >&$_M_FD
			else
				printf "%c" "$_M_C" >&$_M_FD
			fi;;
	esac
}

# Consume standard input one character at a time to render `mustache`(5)
# templates with data from the environment.
mustache() {
	_M_STATE="literal" _M_NEXT_STATE="literal" _M_FD=1

	# IFS must only contain '\n' so as to be able to read space and tab
	# characters from standard input one-at-a-time.  The easiest way to
	# convince it to actually contain the correct byte, and only the
	# correct byte, is to use a single-quoted literal newline.
	IFS='
'

	# Consuming standard input one character at a time is quite a feat
	# within the confines of POSIX shell.  Bash's `read` builtin has
	# `-n` for limiting the number of characters consumed.  Here it is
	# faked using `sed`(1) to place each character on its own line.
	# The subtlety is that real newline characters are chomped so they
	# must be indirectly detected by checking for zero-length
	# characters, which is done in `mustache_literal`.
	sed -r "s/./&\\n/g" | while read _M_C
	do
		echo " _M_C: $_M_C (${#_M_C}), _M_STATE: $_M_STATE" >&2

		case "$_M_STATE" in

			# Start by assuming everything's a literal character.
			"literal") mustache_literal;;

			# Read a possible tag modifier, which sets the next state
			# for the machine, and a tag name.  The tag name will be
			# dealt with in the next state of the machine.
			"tag")
				case "$_M_PREV_C$_M_C" in
					"{{") printf "{" >&$_M_FD;;
					"{#"|"{^"|"{/"|"{!"|"{>") _M_NEXT_STATE="$_M_C" _M_TAG="";;
					"{"*) _M_NEXT_STATE="variable" _M_TAG="$_M_C";;
					"}}") _M_STATE="$_M_NEXT_STATE" _M_NEXT_STATE="";;
					*"}") ;;
					"}"*) _M_TAG="$_M_TAG}";;
					*) _M_TAG="$_M_TAG$_M_C";;
				esac;;

			# Variable tags expand to the value of an environment variable
			# or the empty string if the environment variable is unset.
			#
			# Since the variable tag has been completely consumed, return
			# to the assumption that everything's a literal until proven
			# otherwise for this character.
			"variable")
				eval printf "%s" "\"\$$_M_TAG\"" >&$_M_FD
				mustache_literal;;

			# Section tags expand to the expanded value of the section's
			# literals and tags if and only if the section tag is in the
			# environment and non-empty.
			#
			# Sections not being expanded are redirected to `/dev/null`.
			"#")
				_M_SECTION_TAG="$_M_TAG"
				if [ -n "$(eval printf "%s" "\"\$$_M_TAG\"")" ]
				then
					_M_FD=1
				else
					_M_FD=3
				fi
				# TODO Make a recursive call.
				mustache_literal;;

			# Inverted section tags expand to the expanded value of the
			# section's literals and tags unless the section tag is in
			# the environment and non-empty.
			#
			# Inverted sections not being expanded are likewise
			# redirected to `/dev/null`.
			"^")
				_M_SECTION_TAG="$_M_TAG"
				if [ -z "$(eval printf "%s" "\"\$$_M_TAG\"")" ]
				then
					_M_FD=1
				else
					_M_FD=3
				fi
				# TODO Make a recursive call.
				mustache_literal;;

			# Closing tags for (inverted) sections must match the expected
			# tag name.  Any redirections made when the (inverted) section
			# opened are reset when the section closes.
			"/")
				if [ "$_M_TAG" != "$_M_SECTION_TAG" ]
				then
					mustache_die "mismatched closing tag $_M_TAG," \
						"expected $_M_SECTION_TAG"
				fi
				# TODO Exit the recursive call.
				_M_FD=1
				mustache_literal;;

			# Comments basically do nothing.
			#
			# Once again return to the assumption that everything's a literal
			# until proven otherwise.
			"!") mustache_literal;;

			# TODO Partials.
			">") mustache_die "{{>$_M_TAG}} syntax not implemented";;

		esac

		# This character becomes the previous character.
		_M_PREV_C="$_M_C"

	done
}
