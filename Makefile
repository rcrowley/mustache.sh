VERSION=0.0.0
BUILD=0

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
	sh test.sh

gh-pages:
	shocco lib/mustache.sh >mustache.sh.html+
	git checkout -q gh-pages
	mv mustache.sh.html+ mustache.sh.html
	git add mustache.sh.html
	git commit -m "Rebuilt docs."
	git push origin gh-pages
	git checkout -q master

.PHONY: all clean install uninstall test gh-pages
