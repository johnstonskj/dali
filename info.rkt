#lang info
;;
;; Package dali.
;;   Template generator for Racket
;;
;; Copyright (c) 2018 Simon Johnston (johnstonskj@gmail.com).

(define collection "dali")
(define pkg-desc "Template generator for Racket")
(define version "1.0")
(define pkg-authors '(Simon Johnston))

(define scribblings '(("scribblings/scribblings.scrbl" ())))

(define deps '(
  "base"
  "rackunit-lib"
  "racket-index"))
(define build-deps '(
  "scribble-lib"
  "racket-doc"
  "sandbox-lib"
  "cover-coveralls"))
