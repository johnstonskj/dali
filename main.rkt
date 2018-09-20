#lang racket/base
;;
;; Dali - Text templating for Racket.
;;
;; See:
;;   https://mustache.github.io/
;;   https://handlebarsjs.com/
;;
;; ~ Simon Johnston 2018.
;;

(require racket/contract)

(provide
 (contract-out

  [expand-file
   (->* (path-string? path-string? hash?) ((-> string? string?)) void?)]

  [expand-string
   (->* (string? hash?) ((-> string? string?)) string?)]

  [compile-string
   (-> string? (->* (hash? output-port?) ((-> string? string?)) void?))]

  [load-partial
   (-> string? boolean?)]
  
  [blank-missing-value-handler
   (-> string? string?)])

 partial-path

 partial-cache

 partial-extension)

;; ---------- Requirements

(require racket/bool
         racket/file
         racket/format
         racket/list
         racket/match
         racket/logging
         racket/port
         racket/string)

;; ---------- Implementation - Parameters

;; This has to be at the top-level of the module.
(define-namespace-anchor anchor)

(define partial-path (make-parameter '(".")))

(define partial-cache (make-parameter (hash)))

(define partial-extension (make-parameter ".mustache"))

(define escape-replacements
  (make-parameter '(("&" . "&amp;")
                    ("<" . "&lt;")
                    (">" . "&gt;")
                    ("\"" .  "&quot;")
                    ("'"  . "&#39;"))))

;; ---------- Implementation

(define (blank-missing-value-handler name) "")


(define (expand-file source target context [missing-value-handler blank-missing-value-handler])
  (log-debug "expand ~a ==> ~a" source target)
  (call-with-input-file* source
    (λ (in)
      (let ([str (port->string in)])
        (define compiled (compile-string str))
        (call-with-output-file* target
                                (λ (out)
                                  (compiled context out missing-value-handler)))))))


(define (expand-string str context [missing-value-handler blank-missing-value-handler])
  (define out (open-output-string))
  (define compiled (compile-string str))
  (compiled context out missing-value-handler)
  (get-output-string out))


(define (compile-string str)
  (define this-namespace (namespace-anchor->namespace anchor))
  (eval (compile-string-wrapper str 'top-level) this-namespace))


(define (load-partial file-name)
  (define paths (path-list-string->path-list (partial-path) '()))
  (define file (for/or ([path paths])
                 (define file-path (path-add-extension (build-path path file-name)
                                                       (partial-extension)))
                 (if (file-exists? file-path) file-path #f)))
  (cond
    [(path? file)
     (define compiled (compile-string-wrapper
                       (file->string file)
                       'partial
                       (format "partial:~a" file-name)))
     (cond
       [(false? compiled) #f]
       [else
        (partial-cache (hash-set (partial-cache)
                                 file-name
                                 compiled))
        #t])]
    [else #f]))

;; ---------- Internal procedures

;; The following is a pretty complete match for Moustache/Handlebars
(define moustache
  (regexp "\\{\\{([\\#\\^/!>&]?)(\\{\\s*[^}]*\\s*\\}|\\s*[^}]*\\s*|=\\S+\\s+\\S+=)\\}\\}"))
;; group 0 - the overall match
;; group 1 - any prefix characters
;; group 2 - the embedded tag


(define (compile-string-wrapper str wrapper [name ""])
  (define matches (regexp-match-positions* moustache str #:match-select values))
  (define compiled (if (or (false? matches) (empty? matches))
                       `(display ,str out)
                       (compile-matches str 0 (string-length str) matches
                                        blank-missing-value-handler)))
  (define this-namespace (namespace-anchor->namespace anchor))
  (log-debug str)
  (log-debug (~s compiled))
  (match wrapper
    ['top-level
     `(λ (context out [missing-value-handler blank-missing-value-handler])
           ,compiled)]
    ['partial
     `(define (,(string->symbol name) context out [missing-value-handler blank-missing-value-handler])
           ,compiled)]
    [else
     (error "invalid wrapper form")]))


(define (compile-matches str start end matches missing-value-handler)
  (define compiled '(begin))
  (if (or (false? matches) (empty? matches))
      ;; no matches, simply return any text
      (when (> (- end start) 0)
        (set! compiled (cons `(display ,(substring str start end) out) compiled)))
      ;; loop through all the regex matches
      (let next-match ([last start]
                       [pos-list (first matches)]
                       [more (rest matches)]
                       [skip-to #f])
        (cond
          [(and skip-to (equal? (first skip-to) pos-list))
           (set! skip-to #f)]
          [(not skip-to)
           (let-values ([(prefix value) (prefix-and-value str pos-list)])
             (when (> (- (t-start (first pos-list)) last) 0)
               ;; display any text before match
               (set! compiled
                     (cons `(display ,(substring str last (t-start (first pos-list))) out)
                           compiled)))
             (cond
               [(equal? prefix "!")
                ;; simple comment
                (log-debug "ignoring comment")]
               [(string-between? value "{" "}")
                ;; html escape response
                (set! compiled
                      (cons `(display (escape-string (ref context
                                                          ,(substring-between value 1)
                                                          missing-value-handler)) out)
                            compiled))]
               [(equal? prefix "&")
                ;; html escape response
                (set! compiled
                      (cons `(display (escape-string (ref context
                                                          ,value
                                                          missing-value-handler)) out)
                            compiled))]
               [(string-in? prefix '("#" "^"))
                ;; start a conditional block
                (let ([end (for/or ([end-list more])
                             (let-values ([(e-prefix e-value)
                                           (prefix-and-value str end-list)])
                               (if (and (equal? e-prefix "/")
                                        (equal? e-value value))
                                   (member end-list more)
                                   #f)))])
                  (when (equal? end #f)
                    (error (format "no end tag for block ~a" value)))
                  (define sub-matches (take more (index-of more (first end))))
                  (define not-thing '(missing-or-empty tag-content))
                  (define sub-lambda `(λ (context) ,(compile-matches str
                                                                 (t-end (first pos-list))
                                                                 (t-start (first (first end)))
                                                                 sub-matches
                                                                 missing-value-handler)))
                  (set! compiled
                        (cons `(let ([tag-content (ref context
                                                       ,value
                                                       blank-missing-value-handler)])
                                 (when ,(cond
                                          [(equal? prefix "#") 'tag-content]
                                          [(equal? prefix "^") not-thing])
                                   (let ([new-context (ref context
                                                           ,value
                                                           blank-missing-value-handler)]
                                         [nested ,sub-lambda])
                                     (cond
                                       [(list? new-context)
                                        ;; process each item in the list
                                        (for ([item-context new-context])
                                          ;; this looks like the enclosing cond, minus the list?
                                          (cond
                                            [(hash? item-context)
                                             (nested item-context)]
                                            [(or (symbol? item-context)
                                                 (char? item-context)
                                                 (string? item-context)
                                                 (boolean? item-context)
                                                 (number? item-context))
                                             (nested (hash-set context "_" (~a item-context)))]
                                            [else (error "invalid context type ~s" item-context)]))]
                                       [(hash? new-context)
                                        ;; process once for the hash
                                        (nested new-context)]
                                       [(or (symbol? new-context)
                                            (char? new-context)
                                            (string? new-context)
                                            (boolean? new-context)
                                            (number? new-context))
                                        ;; process once with this value, note we don't change the
                                        ;; context but we add a new key "_" for the current value.
                                        (nested (hash-set context "_" (~a new-context)))]
                                       [else
                                        (error (format "invalid context type: ~s" new-context))]))))
                              compiled))
                  (set! skip-to end))
                (log-debug "handled start section")]
               [(equal? prefix "/")
                (error "unexpected conditional end")]
               [(equal? prefix ">")
                ;; handle partials, include and process nested template
                (define partial (fetch-partial value))
                (cond
                  [(list? partial)
                   (set! compiled (cons partial compiled))
                   (set! compiled
                         (cons `(,(string->symbol (format "partial:~a" value))
                                 context out blank-missing-value-handler)
                               compiled))]
                  [(false? partial)
                   (log-error "partial not found, ignoring: ~s" value)
                   (set! compiled '(missing-value-handler))]
                  [else
                   (error (format "fetch-partial error, unexpected response: ~s" partial))])]
               [(string-prefix? value ".")
                (error "unsupported: relative paths")]
               [(string-between? value "=" "=")
                (error "unsupported: setting delimiters")]
               [else
                ;; just a simple value reference
                (set! compiled
                      (cons `(display (ref context
                                           ,value
                                           missing-value-handler) out)
                            compiled))]))]
          [else (log-debug "skipping over ~a" (substring str last (t-end (first pos-list))))])
        (if (empty? more)
            ;; no more matches, display any trailing text
            (when (> (- end (t-end (first pos-list))) 0)
              (set! compiled (cons `(display ,(substring str (t-end (first pos-list)) end) out)
                                   compiled)))
            ;; process next match
            (next-match (t-end (first pos-list)) (first more) (rest more) skip-to))))
  (reverse compiled))


(define (t-start pair) (car pair))


(define (t-end pair) (cdr pair))


(define (prefix-and-value str a-match)
  (values (substring str (t-start (second a-match)) (t-end (second a-match)))
          (substring-tag str (third a-match))))


(define (substring-tag str position-pair)
  (string-trim (substring str
                          (t-start position-pair)
                          (t-end position-pair))))


(define (substring-between str characters)
  (string-trim (substring str
                          characters
                          (- (string-length str) characters))))


(define (string-between? str prefix suffix)
  (and (string-prefix? str prefix)
       (string-suffix? str suffix)))


(define (string-in? str strings)
  (for/or ([string strings]) (equal? str string)))


(define (missing-or-empty value)
  (cond
    [(boolean? value)
     (not value)]
    [(string? value)
     (not (non-empty-string? value))]
    [else #f]))


(define (ref top-context key missing-value-handler)
  (let nested ([context top-context] [names (string-split key ".")])
    (define value (hash-ref context (first names) (missing-value-handler key)))
    (cond
      [(and (> (length names) 1) (hash? value))
       (nested value (rest names))]
      [(and (= (length names) 1) (procedure? value))
       (if (= (procedure-arity value) 1)
           (value (first names))
           (value))]
      [(= (length names) 1)
       value]
      [else (missing-value-handler key)])))


(define (fetch-partial name)
  (if (hash-has-key? (partial-cache) name)
      (hash-ref (partial-cache) name)
      (if (load-partial name)
          (hash-ref (partial-cache) name)
          #f)))


(define (escape-string str [replace-pairs (escape-replacements)])
  (let next ([in-str str] [replace replace-pairs])
    (define pair (first replace))
    (if (empty? (rest replace))
        in-str
        (next (string-replace in-str (t-start pair) (t-end pair)) (rest replace)))))
