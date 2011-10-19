VERSION=0.0.0
BUILD=1

prefix=/usr/local
bindir=${prefix}/bin
libdir=${prefix}/lib
mandir=${prefix}/share/man

all:

clean:

install:
	install bin/mustache.sh $(DESTDIR)$(bindir)/
	install lib/mustache.sh $(DESTDIR)$(libdir)/

uninstall:
	rm -f $(DESTDIR)$(bindir)/mustache.sh
	rm -f $(DESTDIR)$(libdir)/mustache.sh

test:
	FOO="foo" BAR="bar" bin/mustache.sh <test.mustache | diff -u - test.mustache.out

.PHONY: all clean install uninstall test
