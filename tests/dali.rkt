#lang racket/base
;;
;; dali - dali.
;;   Test cases for the Dali template engine
;;
;; Copyright (c) 2018 Simon Johnston (johnstonskj@gmail.com).

;; ---------- Requirements

(require rackunit
         ; ---------
         "../main.rkt")

;; ---------- Test Fixtures

;; ---------- Internal procedures

(define (myname v) "steve")

;; ---------- Test Cases - Success

(test-case
 "expand-string: success"
 (check-equal?
   (expand-string "hello {{name}} :)" (hash "name" "simon"))
   "hello simon :)"))
  
(test-case
 "expand-string: success with comment"
  (check-equal?
   (expand-string "hello {{!name}} :)" (hash "name" "simon"))
   "hello  :)"))
  
(test-case
 "expand-string: success with lambda value"
  (check-equal?
   (expand-string "hello {{name}} :)" (hash "name" myname))
   "hello steve :)"))
  
(test-case
 "expand-string: success with html unescape &"
  (check-equal?
   (expand-string "hello {{name}} :)" (hash "name" "<simon>"))
   "hello &lt;simon&gt; :)")
  (check-equal?
   (expand-string "hello {{& name}} :)" (hash "name" "<simon>"))
   "hello <simon> :)"))
  
(test-case
 "expand-string: success with html unescape {}"
  (check-equal?
   (expand-string "hello {{name}} :)" (hash "name" "<simon>"))
   "hello &lt;simon&gt; :)")
  (check-equal?
   (expand-string "hello {{{name}}} :)" (hash "name" "<simon>"))
   "hello <simon> :)"))
  
(test-case
 "expand-string: success with nested"
  (check-equal?
   (expand-string "hello {{my.name}} :)" (hash "my" (hash "name" "simon")))
   "hello simon :)"))
  
(test-case
 "expand-string: success with missing key"
  (check-equal?
   (expand-string "hello {{no-name}} :)" (hash "name" "simon"))
   "hello  :)"))

(test-case
 "expand-string: success with missing key, and handler"
  (check-equal?
   (expand-string "hello {{no-name}} :)" (hash "name" "simon") (λ (n) "oops"))
   "hello oops :)"))

(test-case
 "expand-string: success with # conditional and underscore"
 (check-equal?
  (expand-string "{{#name}}Hello {{name}}{{/name}}."
                 (hash "name" "simon"))
  "Hello simon.")
 (check-equal?
  (expand-string "{{#name}}Hello {{_}}{{/name}}."
                 (hash "name" "simon"))
  "Hello simon."))


(test-case
 "expand-string: success with # conditional, list of hashes"
 (define c (hash "items" (list (hash "item" "one")
                               (hash "item" "two")
                               (hash "item" "three"))))
 (check-equal?
  (expand-string "a list: {{#items}}{{item}}, {{/items}}and that's all" c)
  "a list: one, two, three, and that's all"))

(test-case
 "expand-string: success with # conditional list of symbols"
 (check-equal?
  (expand-string "a list: {{#items}}{{_}}, {{/items}}and that's all"
                 (hash "items" '(a b c)))
  "a list: a, b, c, and that's all"))

(test-case
 "expand-string: success with # conditional list of numbers"
 (check-equal?
  (expand-string "a list: {{#items}}{{_}}, {{/items}}and that's all"
                 (hash "items" '(1 3 9)))
  "a list: 1, 3, 9, and that's all"))

(test-case
 "expand-string: success with # conditional hash with hash"
 (check-equal?
  (expand-string "a hash: {{#item}}{{name}}{{/item}} and that's all"
                 (hash "item" (hash "name" "simon")))
  "a hash: simon and that's all"))

(test-case
 "expand-string: success with # conditional hash only"
 (check-equal?
  (expand-string "a hash: {{#item}}{{name}}{{/item}} and that's all"
                 (hash "item" "yes" "name" "simon"))
  "a hash: simon and that's all"))

(test-case
 "expand-string: success with # conditional hash only, no pattern"
 (check-equal?
  (expand-string "a hash: {{#item}}OK then{{/item}} and that's all"
                 (hash "item" "yes"))
  "a hash: OK then and that's all"))

(test-case
 "expand-string: success with # boolean conditional hash only, no pattern"
 (check-equal?
  (expand-string "a hash: {{#item}}OK then{{/item}} and that's all"
                 (hash "item" #t))
  "a hash: OK then and that's all"))

(test-case
 "expand-string: success with # conditional hash only, trailing pattern"
 (check-equal?
  (expand-string "a hash: {{#item}}OK{{/item}} so that's a {{item}}{{^item}}no{{/item}}."
                 (hash "item" "yes"))
  "a hash: OK so that's a yes."))

(test-case
 "expand-string: success with # conditional hash only, trailing pattern"
 (check-equal?
  (expand-string "a hash: {{#item}}OK{{/item}} so that's a {{item}}{{^item}}no{{/item}}."
                 (hash "item" "yes"))
  "a hash: OK so that's a yes."))

(test-case
 "expand-string: success with partial"
 (partial-path (path->string (collection-file-path "tests" "dali")))
 (check-equal?
  (expand-string "{{>salutation}}    Welcome!"
                 (hash "salutation" (hash "text" "Hola"
                                          "title" "Sr"
                                          "sep" ".")
                       "name" "Juan"))
  "Hola Sr. Juan,\n    Welcome!"))


;; tests for compile-string

(test-case
 "compile-string: success with simple string"
 (define compiled-template (compile-string "dummy string"))
 (check-true (procedure? compiled-template))
 (check-true (void? (compiled-template (hash) (open-output-string)))))

(test-case
 "compile-string: success with simple string"
 (define compiled-template (compile-string "hello {{name}}!"))
 (check-true (procedure? compiled-template))
 (define output (open-output-string))
 (compiled-template (hash "name" "simon") output)
 (check-equal?
  (get-output-string output)
  "hello simon!"))

;; tests for load-partial

(test-case
 "load-partial: cannot find file, incorrect name"
 (partial-path (path->string (collection-file-path "tests" "dali")))
 (check-false (load-partial "unknown")))

(test-case
 "load-partial: cannot find file, incorrect path"
 (partial-path (path->string (collection-file-path "unknown" "dali")))
 (check-false (load-partial "salutation")))

;; ---------- Test Cases - Errors

(test-case
 "expand-string: unbalanced conditionals"
  (check-exn
   exn:fail?
   (λ ()
     (expand-string "hello {{#unsupported}} :)" (hash "name" "simon"))))
  (check-exn
   exn:fail?
   (λ ()
     (expand-string "hello {{^unsupported}} :)" (hash "name" "simon"))))
  (check-exn
   exn:fail?
   (λ ()
     (expand-string "hello {{/unsupported}} :)" (hash "name" "simon")))))

;; ---------- Test Cases - Unsupported

(test-case
 "expand-string: unsupported relative path"
  (check-exn
   exn:fail?
   (λ ()
     (expand-string "hello {{../name}} :)" (hash "name" "simon")))))

(test-case
 "expand-string: unsupported set delimiter"
  (check-exn
   exn:fail?
   (λ ()
     (expand-string "hello {{=<% %>=}} :)" (hash "name" "simon")))))
