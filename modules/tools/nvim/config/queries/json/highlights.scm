; Replaces nvim-treesitter's json highlights (no "; extends"), dropping its
; two conceal patterns: they hide every double quote wherever conceallevel > 0,
; which strips the quotes from fenced json blocks in markdown buffers.
[
  (true)
  (false)
] @boolean

(null) @constant.builtin

(number) @number

(pair
  key: (string) @property)

(pair
  value: (string) @string)

(array
  (string) @string)

[
  ","
  ":"
] @punctuation.delimiter

[
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

(escape_sequence) @string.escape

(comment) @comment @spell
