set -e

# Source the `mustache.sh` library.
. "lib/mustache.sh"

# Set some variables.  They don't need to be exported to be made available
# to the `mustache` function.
FOO="foo" BAR="bar"

# Call the `mustache` function, passing a template on standard input and
# diffing standard output against a known-good copy.
mustache <"test.mustache" | diff -u - "test.mustache.out"
