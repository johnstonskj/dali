![Dali Template Engine](https://raw.githubusercontent.com/johnstonskj/dali/master/scribblings/dali-logo-master.png)

[![GitHub release](https://img.shields.io/github/release/johnstonskj/dali.svg?style=flat-square)](https://github.com/johnstonskj/dali/releases)
[![Travis Status](https://travis-ci.org/johnstonskj/dali.svg)](https://www.travis-ci.org/johnstonskj/dali)
[![Coverage Status](https://coveralls.io/repos/github/johnstonskj/dali/badge.svg?branch=master)](https://coveralls.io/github/johnstonskj/dali?branch=master)
[![raco pkg install dali](https://img.shields.io/badge/raco%20pkg%20install-dali-blue.svg)](http://pkgs.racket-lang.org/package/dali)
[![Documentation](https://img.shields.io/badge/raco%20docs-dali-blue.svg)](http://docs.racket-lang.org/dali/index.html)
[![GitHub stars](https://img.shields.io/github/stars/johnstonskj/dali.svg)](https://github.com/johnstonskj/dali/stargazers)
![MIT License](https://img.shields.io/badge/license-MIT-118811.svg)

Dali implements a subset of the languages defined by
[Moustache](https://mustache.github.io/) and [Handlebars](https://handlebarsjs.com/).

## Modules

e `dali` - template engine module.

## Example

```scheme
(require dali)
(define template "a list: {{#items}} {{item}}, {{/items}}and that's all")
(define context (hash "items" (list (hash "item" "one")
                                    (hash "item" "two")
                                    (hash "item" "three"))))
(expand-string template context)
```


## Installation

* To install (from within the package directory): `raco pkg install`
* To install (once uploaded to [pkgs.racket-lang.org](https://pkgs.racket-lang.org/)): `raco pkg install dali`
* To uninstall: `raco pkg remove dali`
* To view documentation: `raco docs dali`

## History

* **1.0** - Initial Version

[![Racket Language](https://raw.githubusercontent.com/johnstonskj/racket-scaffold/master/scaffold/plank-files/racket-lang.png)](https://racket-lang.org/)
