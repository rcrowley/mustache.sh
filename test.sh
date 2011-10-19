set -e

. lib/mustache.sh

FOO="foo" BAR="bar"

mustache <"test.mustache" | diff -u - "test.mustache.out"
