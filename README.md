![Dali Template Engine](https://raw.githubusercontent.com/johnstonskj/dali/master/scribblings/dali-logo-master.png)

[![GitHub release](https://img.shields.io/github/release/johnstonskj/dali.svg?style=flat-square)](https://github.com/johnstonskj/dali/releases)
[![Travis Status](https://travis-ci.org/johnstonskj/dali.svg)](https://www.travis-ci.org/johnstonskj/dali)
[![Coverage Status](https://coveralls.io/repos/github/johnstonskj/dali/badge.svg?branch=master)](https://coveralls.io/github/johnstonskj/dali?branch=master)
[![raco pkg install dali](https://img.shields.io/badge/raco%20pkg%20install-dali-blue.svg)](http://pkgs.racket-lang.org/package/dali)
[![Documentation](https://img.shields.io/badge/raco%20docs-dali-blue.svg)](http://docs.racket-lang.org/dali/index.html)
[![GitHub stars](https://img.shields.io/github/stars/johnstonskj/dali.svg)](https://github.com/johnstonskj/dali/stargazers)
![MIT License](https://img.shields.io/badge/license-MIT-118811.svg)

Dali is a [Racket](https://racket-lang.org/) implementation of a language similar to [Mustache](https://mustache.github.io/) and [Handlebars](https://handlebarsjs.com/). It tries to be as faithful as possible to Mustache, providing a simple and high-level idiomatic module for callers. Not all features of Handlebars are implemented, or implemented in the same manner, as they are more JavaScript focused.

## Modules

* `dali` - template engine module, provides `compile-string`, `expand-string`, and `expand-file` functions for template expansion. The *expand* functions rely on the *compile* function to read the template and convert it into a Racket function for performance and re-use.

## Example

The following example expands a very simple template with a nested list. Note that the context provided to the expansion function is simply comprised of `hash?` and `list?` structures.

```scheme
(require dali)
(define template "a list: {{#items}} {{item}}, {{/items}}and that's all")
(define context (hash "items" (list (hash "item" "one")
                                    (hash "item" "two")
                                    (hash "item" "three"))))
(expand-string template context)
```

The module also provides a cache for loaded and compiled *partial* to support greater performance.

## Installation

* To install (from within the package directory): `raco pkg install`
* To install (once uploaded to [pkgs.racket-lang.org](https://pkgs.racket-lang.org/)): `raco pkg install dali`
* To uninstall: `raco pkg remove dali`
* To view documentation: `raco docs dali`

## History

* **1.0** - Initial Version

[![Racket Language](https://raw.githubusercontent.com/johnstonskj/racket-scaffold/master/scaffold/plank-files/racket-lang.png)](https://racket-lang.org/)
