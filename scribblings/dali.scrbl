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
@title[#:version "1.0"]{Package dali}
@author[(author+email "Simon Johnston" "johnstonskj@gmail.com")]

Dali is a @hyperlink["https://racket-lang.org/"]{Racket} implementation of a
language similar to @hyperlink["https://mustache.github.io/"]{Mustache} and
@hyperlink["https://handlebarsjs.com/"]{Handlebars}. It tries to be as faithful
as possible to Mustache, providing a simple and high-level idiomatic module for
callers. Not all features of Handlebars are implemented, or implemented in the
same way as they are more JavaScript focused.

The first part of this page describes the supported template language, any
deviations from Mustache, and any Racket-specific features. It then goes on to
describe @secref["Module_dali"] itself and the its operation.

The @racket[dali] module provides @racket[compile-string],
@racket[expand-string], and @racket[expand-file] functions for template expansion.
The @italic{expand} functions rely on the @italic{compile} function to read the
template and convert it into a Racket function for performance and re-use.

@;{============================================================================}
@;{============================================================================}
@section[]{Template Language}

Dali implements features from the languages defined by
@hyperlink["https://mustache.github.io/"]{Mustache} and
@hyperlink["https://handlebarsjs.com/"]{Handlebars}. The following section
describes the language in more detail and use the same outline structure as the
Mustache man page. As with Mustache, the template comprises plain text with
embedded @italic{tags} where these are indicated by bounding @italic{double
mustaches}, as in @tt{@"{{"person@"}}"}. Tags have different processing depending
on their specific meaning, as described in the sections below.

In Dali the @italic{context} that provides tag replacement values is simply a
@racket[hash?] with @racket[string?] keys and values that may be a nested hash,
a @racket[list?], or a single value (@racket[symbol?], @racket[string?],
@racket[char?], @racket[boolean?], or @racket[number?]). This allows for simple
and familiar construction of contexts and more readable code when invoking
expansion functions.

@;{============================================================================}
@subsection{Variables}

Variables are specified between @tt{@"{{"} and @tt{@"}}"}. On encountering a
variable the text of the tag is assumed to be a key present in the current
context and the corresponding value is returned as a replacement. When the
key is not found the expansion functions have a @racket[missing-value-handler]
parameter which is a function that takes the key and returns a string
value. The @racket[dali] module provides an implementation
(@racket[blank-missing-value-handler]) which simply returns an empty string, as well
as another (@racket[error-missing-value-handler]) which raises @racket[exn:fail].

Note, Dali @italic{does not} search up the context for the tag name, it only
considers the current context; see @secref["Paths"] and @secref["Parent_Paths"]
for alternative mechanisms.

All variables are HTML-escaped by default. Variables specified between @tt{@"{{{"}
and @tt{@"}}}"}, or with the tag prefix @tt{&} (special characters between 
the opening mustache and key), @italic{will not}
HTML-escape their content.

@bold{Template:}

@verbatim|{
* {{name}}
* {{age}}
* {{company}}
* {{{company}}}
* {{&company}}
}|

@bold{Context:}

@racketblock[
(hash "name" "Chris"
      "company" "<b>GitHub</b>")
]

@bold{Output:}

@verbatim|{
* Chris
*
* &lt;b&gt;GitHub&lt;/b&gt;
* <b>GitHub</b>
* <b>GitHub</b>
}|

@subsubsection[#:tag "value:lambda"]{Lambdas}

Any value may be a be a lambda, specifically a lambda that takes a single
argument which will be the key used to select it. The lambda returns a
string value that will be used as the replacement value.

@racketblock[
(require racket/date)
(expand-string template (hash "name" "Chris"
                              "date" (λ (k) (date->string (current-date)))))
]

The corresponding contract for the lambda is therefore:

@racketblock[
[value-lambda (-> string? string?)]
]

@;{============================================================================}
@subsection{Sections}

Sections render blocks of text one or more times, depending on the value
of the key in the current context. Sections start with the @tt{#} tag prefix
and end with the @tt{/} tag prefix. The following sub-sections outline the
specific behavior of sections based on the type of the tag value.

@subsubsection{False Values or Empty Lists}

If the key exists and has a false value (one of @racket[#f], @racket[""],
@racket[0], @racket['()], or @racket[#hash()]) the tag content @italic{will not}
be displayed.

@bold{Template:}

@verbatim|{
Shown.
{{#person}}
  Never shown!
{{/person}}
}|

@bold{Context:}

@racketblock[
(hash "person" #f)
]

@bold{Output:}

@verbatim|{
Shown.
}|

@subsubsection{Non-Empty Lists}

If the key exists and is a non-empty list the tag content will be rendered once
for each item in the list. In the case that the item is itself a hash value
the context for each render will be reset to be the list item.

@bold{Template:}

@verbatim|{
{{#repo}}
  <b>{{name}}</b>
{{/repo}}
}|

@bold{Context:}

@racketblock[
(hash "repo" (list (hash "name" "resque")
                   (hash "name" "hub")
                   (hash "name" "rip")))
]

@bold{Output:}

@verbatim|{
<b>resque</b>
<b>hub</b>
<b>rip</b>
}|

If, however, the list contains single valued items the context is not reset but
a temporary key @tt{"_"} is added to the context with the value of the list item 
(see @secref["Self-Reference"]).

@bold{Template:}

@verbatim|{
{{#repo}}
  <b>{{_}}</b>
{{/repo}}
}|

@bold{Context:}

@racketblock[
(hash "repo" (list "resque" "hub" "rip"))
]

@bold{Output:}

@verbatim|{
<b>resque</b>
<b>hub</b>
<b>rip</b>
}|

@subsubsection[#:tag "section:lambda"]{Lambdas}

If the key exists and the value is a @racket[procedure?], and specifically one
with a @racket[procedure-arity] of 2, it will be called to return a replacement
value. Unlike value @secref["value:lambda"] above, instead of being passed the key
the lambda is passed the unexpanded content of the section. The second parameter
is a function that when called will be able to render the provided text.

This is currently unsupported/untested.

@bold{Template:}

@verbatim|{
{{#wrapped}}
  {{name}} is awesome.
{{/wrapped}}
}|

@bold{Context:}

@racketblock[
(hash "name" "willy"
      "wrapped" (λ (text render)
                  (format "<b>~a</b>" (render))))
]

@bold{Output:}

@verbatim|{
<b>Willy is awesome.</b>
}|

@subsubsection{Non-False Values}

If the key exists, it is not a list, we assume it is a nested @racket[hash?]
and will be used as the context for rendering the section.

@bold{Template:}

@verbatim|{
{{#person?}}
  Hi {{name}}!
{{/person?}}
}|

@bold{Context:}

@racketblock[
(hash "person?" (hash "name" "Jon"))
]

@bold{Output:}

@verbatim|{
Hi Jon!
}|

@subsection{Inverted Sections}

If the tag prefix is a caret, @tt{^}, the section renders based on the inverse
of the logical tests above. For example, such a section will render if the key
does not exist, is a false value, the empty list or an empty hash.

@bold{Template:}

@verbatim|{
{{#repo}}
  <b>{{name}}</b>
{{/repo}}
{{^repo}}
  No repos :(
{{/repo}}
}|

@bold{Context:}

@racketblock[
(hash "repos" '())
]

@bold{Output:}

@verbatim|{
No repos :(
}|

@;{============================================================================}
@subsection{Paths}

A tag can reference nested values, i.e. a hash within a hash, using a dotted
name such as @tt{parent-name.child-name} (a Handlebars feature). Each name in
the path is assumed to reference a hash value (except the last) and if not
it will be treated as a missing value. Therefore the following template:

@bold{Template:}

@verbatim|{
{{#name}}Hello {{person.name}}.{{/name}}
}|

@bold{Context:}

@racketblock[
(hash "person" (hash "name" "Chris"))
]

@bold{Output:}

@verbatim|{
Hello Chris.
}|

@subsubsection{Parent Paths}

Handlebars also supports references to the parent context via the use of
relative path specifiers (@tt{../}). For example, in the following template
the @tt{#person}} section will change the context within the section to the
nested hash value but the salutation key exists in the parent context.

@bold{Template:}

@verbatim|{
{{#person}}{{../salutation}} {{name}}.{{/person}}
}|

@bold{Context:}

@racketblock[
(hash "salutation" "Hello"
      "person" (hash "name" "Chris"))
]

@bold{Output:}

@verbatim|{
Hello Chris.
}|

@subsubsection{Self-Reference}

Sometimes, the logic for a template is such that we use a conditional section
as a guard around a single value, for example:

@bold{Template:}

@verbatim|{
{{#name}}Hello {{name}}.{{/name}}
}|

@bold{Context:}

@racketblock[
(hash "name" "Chris")
]

@bold{Output:}

@verbatim|{
Hello Chris.
}|

While this is a perfectly reasonable approach, sometimes it feels verbose to
re-type the name tag three times. Dali supports a shortcut for reference inside
a section to the value of the section, the underscore character. Therefore, the
following template is equivalent to the example above.

@verbatim|{
{{#name}}Hello {{_}}.{{/name}}
}|

@;{============================================================================}
@subsection{Comments}

Variables with a @tt{!} prefix character are treated as comments and ignored.


@bold{Template:}

@verbatim|{
<h1>Today{{! ignore me }}.</h1>
}|

@bold{Output:}

@verbatim|{
<h1>Today.</h1>}|


Handlebars provides the extended @tt{!-- --} comment form, but as this shares
the same prefix "!" it is supported by default.

@;{============================================================================}
@subsection{Partials}

Variables with the prefix @tt{>} are used to incorporate the content of a separate
template file, a reusable part of the larger template. The key is not used to
look up any value in the context but is taken to be the name of a file (with
the default extension ".mustache") to be transcluded into the template at runtime.

Dali only loads a partial on its first reference, it compiles it and uses a
cache to refer to it at render time. This allows a partial to be used in multiple
places in a template, or even in multiple templates, without re-processing.

@bold{Partial (base.mustache):}

@verbatim|{
<h2>Names</h2>
{{#names}}
  {{> user}}
{{/names}}
}|

@bold{Template:}

@verbatim|{
<strong>{{name}}</strong>
}|

Will be combined as if it were a single expanded template:

@verbatim|{
<h2>Names</h2>
{{#names}}
  <strong>{{name}}</strong>
{{/names}}
}|

@;{============================================================================}
@subsection{Set Delimiter}

Currently Unsupported.

@;{============================================================================}
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

@;{============================================================================}
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
The file extension for partial files, by default this is @tt{.mustache}.
}

@;{============================================================================}
@subsection[]{Template Expansion}

@defproc[(expand-file
          [source path-string?]
          [target path-string?]
          [context hash?]
          [missing-value-handler (-> string? string?) blank-missing-value-handler])
         void?]{
This function will read the file @racket[source], process with @racket[expand-string],
and write the result to the file @racket[target]. It will raise @racket[exn:fail] if
the source file @italic{does not} exist, or if the target file @italic{does} exist.
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

This function may raise @racket[exn:fail] for the following conditions.

@itemlist[
  @item{Invalid context structure}
  @item{Partial file does not exist}
  @item{Unsupported feature}
]
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
This is the default @racket[missing-value-handler] function, it simply returns a
blank string (@racket[""]) for any missing context key.}

@defproc[(error-missing-value-handler
          [name string?])
         string?]{
This handler can be used to raise @racket[exn:fail] for any missing context key.}
