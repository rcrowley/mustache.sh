mustache.sh
===========

Installation
------------

Early days, yo.  It's just one file so put it on your `PATH`.

Usage
-----

	FOO="foo" BAR="bar" sh mustache.sh <test.mustache

Spec
----

* [`mustache`(1)](http://mustache.github.com/mustache.1.html)
* [`mustache`(5)](http://mustache.github.com/mustache.5.html)

Deviations from spec
--------------------

* `mustache.sh` accepts input data via the environment, not via YAML frontmatter.  This makes sense for shell programmers but may render this Mustache implementation unsuitable for other use.
* `mustache.sh` does not descend into a new scope within <code>{{#<em>tag</em>}}</code> or <code>{{^<em>tag</em>}}</code> sections.  This again makes sense when being driven by environment variables.

TODO
----

* List sections.
* Lambdas.
* Nested sections.
* Partials.
* Set delimeter.

TODONE
------

* Variable tags.
* Section tags.
* Inverted section tags.
* Comment tags.
