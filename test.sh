set -e

# Source the `mustache.sh` library.
. "lib/mustache.sh"

# Set some variables.  They don't need to be exported to be made available
# to the `mustache` function.
FOO="foo" BAR="bar"

# Call the `mustache` function, passing a template on standard input and
# diffing standard output against a known-good copy.
find "tests" -type f -name "*.mustache" | while read PATHNAME
do
	echo "$PATHNAME" >&2
	mustache <"$PATHNAME" | diff -u - "$PATHNAME.out"
done
