# `mustache.sh`, Mustache in POSIX shell.

set -e

# File descriptor 3 is commandeered for use as a sink for literal and
# variable output of (inverted) sections that are not destined for standard
# output because their condition is not met.
exec 3>/dev/null

# File descriptor 4 is commandeered for debug output, which may end up being
# forwarded to standard error.
[ -z "$MUSTACHE_DEBUG" ] && exec 4>/dev/null || exec 4>&2

# Consume standard input one character at a time to render `mustache`(5)
# templates with data from the environment.
mustache() {

	# Initialize the file descriptor to be used to emit characters.  At
	# times this value will be 3 to send output to `/dev/null`.
	_M_FD=1

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
	# characters, which is done as the character is emitted.
	sed -r "s/./&\\n/g" | _mustache

	# TODO Replace the original value of IFS.  Be careful if it's unset.

}

# Process the one-character-per-line stream from `sed` via a state machine.
# This function will be called recursively in subshell environments to
# isolate nested section tags from the outside environment.
_mustache() {

	# Always start by assuming a character is a literal.
	_M_STATE="literal"

	while read _M_C
	do
		echo " _M_C: $_M_C (${#_M_C}), _M_STATE: $_M_STATE" >&4
		case "$_M_STATE" in

			# Consume a single character literal.  In the event this
			# character and the previous character have been opening
			# braces, progress to the "tag" state and initialize the
			# tag name to the empty string (this invariant is relied
			# on by the "tag" state).  If this is the first opening
			# brace, wait and see.  Otherwise, emit this character.
			"literal")
				case "$_M_PREV_C$_M_C" in
					"{{") _M_STATE="tag" _M_TAG="";;
					*"{") ;;
					*)
						[ "$_M_PREV_C" = "{" ] && printf "%c" "{"
						[ -z "$_M_C" ] && echo || printf "%c" "$_M_C";;
				esac >&$_M_FD;;

			# Consume the tag type and tag.
			"tag")
				case "$_M_PREV_C$_M_C" in

					# A third opening brace in a row could be treated as
					# a literal and the beginning of tag, as it is here,
					# or as the beginning of a tag which begins with an
					# opening brace.
					"{{") printf "{" >&$_M_FD;;

					# Note the type of this tag, defaulting to "variable".
					"{#"|"{^"|"{/"|"{!"|"{>") _M_TAG_TYPE="$_M_C" _M_TAG="";;

					# A variable tag must note the first character of the
					# variable name.  Since it's possible that an opening
					# brace comes in the middle of the tag, check that
					# this is indeed the beginning of the tag.
					"{"*)
						if [ -z "$_M_TAG" ]
						then
							_M_TAG_TYPE="variable" _M_TAG="$_M_C"
						fi;;

					# Two closing braces in a row closes the tag.  The
					# state resets to "literal" and the tag is processed,
					# possibly in a subshell.
					"}}")
						_M_STATE="literal"
						_mustache_tag;;

					# A single closing brace is ignored at first.
					*"}") ;;

					# If the variable continues, the closing brace becomes
					# part of the variable name.
					"}"*) _M_TAG="$_M_TAG}";;

					# Any other character becomes part of the variable name.
					*) _M_TAG="$_M_TAG$_M_C";;

				esac;;

		esac

		# This character becomes the previous character.
		_M_PREV_C="$_M_C"

	done
}

# Print an error message and GTFO.
_mustache_die() {
	echo "mustache.sh: $@" >&2
	exit 1
}

# Process a complete tag.  Variables are emitted, sections are recursed
# into, comments are ignored, and (for now) partials raise an error.
_mustache_tag() {
	case "$_M_TAG_TYPE" in

		# Variable tags expand to the value of an environment variable
		# or the empty string if the environment variable is unset.  If
		# the tag is surrounded by backticks, execute it as a shell
		# command, instead, using standard output as its value.
		#
		# Since the variable tag has been completely consumed, return
		# to the assumption that everything's a literal until proven
		# otherwise for this character.
		"variable")
			case "$_M_TAG" in
				"\`"*"\`")
					_M_TAG="${_M_TAG#"\`"}"
					_M_TAG="${_M_TAG%"\`"}"
					sh -c "$_M_TAG" >&$_M_FD;;
				*) eval printf "%s" "\"\$$_M_TAG\"" >&$_M_FD;;
			esac;;

		# Section tags expand to the expanded value of the section's
		# literals and tags if and only if the section tag is in the
		# environment and non-empty.  Inverted section tags expand
		# if the section tag is empty or unset in the environment.
		#
		# Sections not being expanded are redirected to `/dev/null`.
		"#"|"^")
			echo " # _M_TAG: $_M_TAG" >&4
			_M_TAG_V="$(eval printf "%s" "\"\$$_M_TAG\"")"
			case "$_M_TAG_TYPE" in
				"#") [ -n "$_M_TAG_V" ] && _M_FD=1 || _M_FD=3;;
				"^") [ -z "$_M_TAG_V" ] && _M_FD=1 || _M_FD=3;;
			esac
			(
				_M_SECTION_TAG="$_M_TAG"
				_mustache
			)
			_M_FD=1;;

		# Closing tags for (inverted) sections must match the expected
		# tag name.  Any redirections made when the (inverted) section
		# opened are reset when the section closes.
		"/")
			echo " / _M_TAG: $_M_TAG, _M_SECTION_TAG: $_M_SECTION_TAG" >&4
			if [ "$_M_TAG" != "$_M_SECTION_TAG" ]
			then
				_mustache_die "mismatched closing tag $_M_TAG," \
					"expected $_M_SECTION_TAG"
			fi
			exit;;

		# Comments do nothing.
		"!") ;;

		# TODO Partials.
		">") _mustache_die "{{>$_M_TAG}} syntax not implemented";;

	esac
}
