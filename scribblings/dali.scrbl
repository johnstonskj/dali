#lang scribble/manual

@(require racket/sandbox
          scribble/core
          scribble/eval
          dali
          (for-label racket/base
                     racket/contract
                     dali))

@;{============================================================================}

@(define example-eval (make-base-eval
                      '(require racket/string
                                dali)))

@;{============================================================================}
@;{============================================================================}
@title[#:version "1.0"]{Package Dali}
@author[(author+email "Simon Johnston" "johnstonskj@gmail.com")]

TBD

@table-of-contents[]

@;{============================================================================}
@;{============================================================================}
@section[]{Template Language}

Dali implements a subset of the languages defined by
@hyperlink["https://mustache.github.io/"]{Moustache} and
@hyperlink["https://handlebarsjs.com/"]{Handlebars}. Specifically, the following
section describes the language in more detail.

@subsection{Variables}

Variables are specified between @tt{@"{{"} and @tt{@"}}"}. Variables specified
between @tt{@"{{{"} and @tt{@"}}}"}, or with the prefix character @tt{&}, will
HTML-escape their content.

@verbatim|{
* {{name}}
* {{age}}
* {{company}}
* {{{company}}}
}|

and

@racketblock[
(expand-string template (hash "name" "Chris"
                              "company" "<b>GitHub</b>"))
]

@verbatim|{
* Chris
*
* &lt;b&gt;GitHub&lt;/b&gt;
* <b>GitHub</b>
}|

@subsubsection{Paths}

keys may be nested, i.e. @tt{name.name}.

@subsubsection{Parent Paths}

relative context specfication (use of @tt{./} or @tt{../} etc) is unsupported.}

@subsection{Sections}

conditionals (starting with either @tt{#} or @tt{^} and closing with @tt{/}) are supported.

@subsubsection{False Values or Empty Lists}

@subsubsection{Non-Empty Lists}

@subsubsection{Lambdas}

@subsubsection{Non-False Values}

@subsection{Inverted Sections}

@subsection{Comments}

Variables with a @tt{!} prefix character are treated as comments and ignored.

@verbatim|{
<h1>Today{{! ignore me }}.</h1>

...

<h1>Today.</h1>
}|

Handlebars @tt{!-- --} supported by default.

@subsection{Partials}

@subsection{Set Delimiter}

Currently Unsupported.

@subsection{Helpers and Literals}

Currently unsupported (from Handlebars).

@;{============================================================================}
@;{============================================================================}
@section[]{Module dali}
@defmodule[dali]

This module implements the @italic{Dali} template engine.

@examples[ #:eval example-eval
(require dali)
(code:comment @#,elem{high-level function: expand-string})
(define template "a list: {{#items}} {{item}}, {{/items}}and that's all")
(define context (hash "items" (list (hash "item" "one")
                                    (hash "item" "two")
                                    (hash "item" "three"))))
(expand-string template context)
(code:comment @#,elem{lower-level function: compile-string})
(define compiled-template (compile-string "hello {{name}}!"))
(define output (open-output-string))
(compiled-template (hash "name" "simon") output)
(get-output-string output)
]

@subsection[]{Parameters}

The following parameters are all used during the processing of @italic{partial}
blocks, external templates that are incorporated into the parent. Primarily these
affect the behavior of @racket[load-partial] which finds, loads, and compiles
external files and adds them to the @racket[partial-cache]. This cache is then
used by @racket[compile-string] to fetch and include partials.

@defthing[partial-path (listof stting?)]{
A list of strings that are used to search for partial files to load.
}

@defthing[partial-cache (hash/c string? list?)]{
A hash from partial name to the semi-compiled form (i.e. to a quoted list that will be
incorporated into the final compiled form).
}

@defthing[partial-extension string?]{
The file extension for partial files, by default this is @tt{.moustache}.
}

@subsection[]{Template Expansion}

@defproc[(expand-file
          [source path-string?]
          [target path-string?]
          [context hash?]
          [missing-value-handler (-> string? string?) blank-missing-value-handler])
         void?]{
This function will read the file @racket[source], process with @racket[expand-string],
and write the result to the file @racket[target]. It will raise an error if
the target file already exists.
}

@defproc[(expand-string
          [source string?]
          [context hash?]
          [missing-value-handler (-> string? string?) blank-missing-value-handler])
         string?]{
This function will treat @racket[source] as a template, compile it with
@racket[compile-string], evaluate it with the provided context and return the
result as a string.

A context is actually defined recursively as @racket[(hash/c string? (or/c string? list? hash?))]
so that the top level is a hash with string keys and values which are either lists
or hashes with the same contract.

The @racket[missing-value-handler] is a function that will be called when the key
in a template is not found in the context, it is provided the key content and
any value it returns is used as the replacement text.}

@defproc[(compile-string
          [source string?])
         (->* (hash? output-port?) ((-> string? string?)) void?)]{
This function will compile a template into a function that may be called with a
context @racket[hash?] and an @racket[output-port?] to generate content.

The generated compiled form can be thought of as a new function with the
following form.

@racketblock[
(λ (context out [missing-value-handler blank-missing-value-handler])
  ...
  (void))
]

}

@defproc[(load-partial
          [name string?])
         boolean?]{
Find a file with @racket[name] and extension @racket[partial-extension], in the 
search paths specified by @racket[partial-path]. Load the file, compile it and
add it to @racket[partial-cache]. Returns @racket[#t] if this is successful, or
@racket[#f] on error.
}

@defproc[(blank-missing-value-handler
          [name string?])
         string?]{
This is the default missing-value-handler function, it simply returns a blank
string for any missing template key.}
