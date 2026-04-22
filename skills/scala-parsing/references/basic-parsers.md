# Basic Parser Reference

Exhaustive API reference for FastParse basic combinators, character classes, parse results,
error reporting, and common patterns. This goes beyond the SKILL.md overview.

---

## Whitespace Handling Modes

FastParse has two whitespace modes that fundamentally change how parsers behave between tokens.

### NoWhitespace Mode

```scala
import fastparse._
import fastparse.NoWhitespace._

// Parsers match exactly — no implicit whitespace
def pair[_: P] = P("hello" ~ "world")
// Matches: "helloworld"     Does NOT match: "hello world"
```

Use NoWhitespace when:
- Parsing formats with no whitespace tolerance (JSON keys, tokens, binary-like formats)
- You need exact control over where whitespace is allowed
- Performance matters — implicit whitespace adds overhead to every `~` operator
- Parsing programming languages where whitespace is significant (Python, YAML)

### Default (Implicit Whitespace) Mode

```scala
import fastparse._

// Whitespace is implicitly consumed between every ~ operator
def greeting[_: P] = P("hello" ~ "world")
// Matches: "helloworld", "hello world", "hello  world", "hello\n\tworld"
```

The default mode calls an implicit whitespace parser between every `~`. The default whitespace
parser matches `CharIn(" \t\n\r").rep`.

### Custom Whitespace Handling

```scala
import fastparse._

// Override the implicit whitespace parser
implicit def customWhitespace[_: P]: P[Unit] = P(" ".rep)  // only spaces, not newlines

def lineParser[_: P] = P("key" ~ ":" ~ "value")
// Now newlines are significant — only spaces are eaten between tokens
```

```scala
// Comment-aware whitespace (for programming languages)
def comment[_: P]: P[Unit] = P("//" ~ CharsWhile(_ != '\n') | "/*" ~ (!"*/" ~ AnyChar).rep ~ "*/")

implicit def whitespaceWithComments[_: P]: P[Unit] = P(NoCut((comment | CharIn(" \t\n\r")).rep))
```

### Mixing Modes Within a Parser

```scala
// Switch to NoWhitespace for a sub-parser using NoCut or explicit whitespace
def token[_: P] = P(CharIn("a-zA-Z_").rep(1)).!

def quotedString[_: P] = {
  // Inside quotes, use NoWhitespace for exact matching
  import fastparse.NoWhitespace._
  P("\"" ~/ CharsWhile(_ != '"').! ~/ "\"")
}
```

---

## Parse Result Type Reference

### Parsed.Success

```scala
result match {
  case Parsed.Success(value, index) =>
    // value: T — the captured/transformed result from the parser
    // index: Int — the index in the input string where parsing stopped

    // For P[Unit] parsers, value is ()
    // For P[String] parsers (using .!), value is the captured string
    // For P[MyType] parsers (using .map), value is the mapped type
}
```

### Parsed.Failure

```scala
result match {
  case f: Parsed.Failure =>
    val label: String = f.label          // Name of the failing parser
    val index: Int = f.index             // Position where failure occurred
    val extra: Parsed.Extra = f.extra    // Additional context

    // Extra gives access to:
    val input: String = f.extra.input       // Original input string
    val index: Int = f.extra.index          // Alias for failure index
    val tracer: Parsed.Tracer = f.extra     // Trace context

    // Get detailed trace showing all attempted parsers
    val traced: Parsed.Trace = f.trace()
    val traceStr: String = traced.trace     // Stack trace of parser calls
    // Shows something like:
    //   Expected expr:1:1 / term:1:1 / factor:1:1 / "(":1:1 ..."abc"

    // Full stack trace with all attempted alternatives
    val fullTrace: String = traced.fullStackTrace
    // Shows all alternatives tried at each level

    // Aggregate errors from all failed branches
    val grouped: String = traced.groupedTrace
    // Groups failures by location for cleaner output
}
```

### Converting Failure to Error Message

```scala
def parseOrError(input: String, parser: P[_] => P[_]): Either[String, _] = {
  fastparse.parse(input, parser) match {
    case Parsed.Success(value, _) => Right(value)
    case f: Parsed.Failure =>
      val trace = f.trace()
      Left(s"Parse error at position ${f.index}: ${trace.label}\n${trace.trace}")
  }
}
```

---

## Error Reporting Deep Dive

### Using `.trace()` for Detailed Diagnostics

```scala
val result = fastparse.parse("hello xorld", greetingParser(_))
result match {
  case f: Parsed.Failure =>
    println(f.trace().trace)
    // Shows the full chain of parser calls leading to the failure
    // e.g., "Expected greetingParser:1:1 / "world":1:6 ..."
}
```

### Using `.label()` for Custom Error Labels

```scala
def keyword[_: P] = P("if" | "else" | "while" | "for").!.label("keyword")

def number[_: P] = P(CharIn("0-9").rep(1)).!.label("integer")

def parser[_: P] = P(keyword ~ "(" ~ number ~ ")")
// On failure, error message says "expected keyword" or "expected integer"
// instead of the raw parser internals
```

### Customizing Failure Messages

```scala
// Fail with a custom message at a specific point
def identifier[_: P] = P(
  CharIn("a-zA-Z_").rep(1).!.flatMap { name =>
    if (reservedWords.contains(name))
      Fail(s"'$name' is a reserved word")
    else
      Pass(name)
  }
)

// Conditional failure with custom message
def positiveInt[_: P] = P(
  CharIn("0-9").rep(1).!.map(_.toInt).flatMap { n =>
    if (n > 0) Pass(n) else Fail("expected positive integer")
  }
)
```

### Aggregate Errors (Collecting Multiple Errors)

```scala
// FastParse doesn't natively collect multiple errors, but you can
// parse in segments and collect failures
def parseAll(input: String): Either[List[String], List[Result]] = {
  val errors = scala.collection.mutable.ListBuffer[String]()
  val results = scala.collection.mutable.ListBuffer[Result]()

  input.linesIterator.foreach { line =>
    fastparse.parse(line, lineParser(_)) match {
      case Parsed.Success(value, _) => results += value
      case f: Parsed.Failure => errors += s"Line error: ${f.trace().label}"
    }
  }

  if (errors.nonEmpty) Left(errors.toList) else Right(results.toList)
}
```

---

## Advanced Repetition Options

### Complete `.rep()` API

```scala
// Zero or more (default)
P(item.rep)              // matches 0..N items

// Minimum count
P(item.rep(1))           // matches 1..N items (one or more)
P(item.rep(3))           // matches 3..N items

// Bounded (min, max)
P(item.rep(1, 5))        // matches 1..5 items

// With separator
P(item.rep(sep = ","))         // items separated by ","
P(item.rep(sep = "," ~/))      // items separated by "," with cut

// Separator + bounds
P(item.rep(1, sep = ","))      // 1+ items separated by ","
P(item.rep(2, 10, sep = ","))  // 2..10 items separated by ","

// Exact count (shorthand)
P(item.rep(3))                  // exactly 3 or more
P(item.repExactly(3))           // exactly 3

// Rep with capture
P(digit.rep(1).!)               // captures entire repeated match as one string
P(digit.!.rep(1))               // captures each repetition individually (Seq[String])
```

### Bounded Repetition Patterns

```scala
// Parse a date in YYYY-MM-DD format with exact digit counts
def date[_: P] = P(
  CharIn("0-9").rep(exactly = 4).! ~ "-" ~/ CharIn("0-9").rep(exactly = 2).! ~ "-" ~/ CharIn("0-9").rep(exactly = 2).!
)

// Parse a MAC address: XX:XX:XX:XX:XX:XX
def hexPair[_: P] = P(CharIn("0-9a-fA-F").rep(exactly = 2)).!
def macAddress[_: P] = P(hexPair.rep(exactly = 6, sep = ":"))

// Parse comma list of 1-10 items
def boundedList[_: P] = P(item.rep(1, 10, sep = "," ~/))
```

---

## Character Class Reference

### Complete Character Combinators

| Combinator | Description | Example |
|---|---|---|
| `CharIn("a-z")` | Character in range/set | `CharIn("0-9a-fA-F")` — hex digit |
| `CharPred(f)` | Character matching predicate | `CharPred(_.isLetter)` |
| `CharsWhileIn("a-z")` | One or more chars in set | `CharsWhileIn("0-9")` — digits |
| `CharsWhile(f)` | One or more chars matching predicate | `CharsWhile(_.isWhitespace)` |
| `StringIn("a","b")` | Match one of multiple strings | `StringIn("true","false")` |
| `AnyChar` | Match any single character | `AnyChar` |
| `CharIn("a-z","A-Z")` | Multiple ranges | Alphabetic characters |

### CharIn Syntax

```scala
// Ranges
CharIn("0-9")          // '0' through '9'
CharIn("a-z")          // 'a' through 'z'
CharIn("A-Z")          // 'A' through 'Z'
CharIn("0-9a-fA-F")    // hex digits — ranges concatenate

// Literal characters
CharIn("abc")          // 'a', 'b', or 'c'
CharIn("+\\-*/")       // operators (escape hyphen with \\)

// Mixed
CharIn("0-9_")         // digits or underscore

// Negation with CharsWhileIn
CharsWhileIn(!"\"")     // chars that are NOT double-quote
CharsWhileIn(!" \t\n")  // chars that are NOT whitespace

// CharsWhile with predicate
CharsWhile(c => c.isLetter || c == '_')  // identifier chars
CharsWhile(_ != '\n')                     // everything except newline
```

### Unicode Categories

```scala
// FastParse doesn't have built-in Unicode categories, use CharPred:
def unicodeLetter[_: P] = P(CharPred(_.isLetter))           // any Unicode letter
def unicodeDigit[_: P] = P(CharPred(_.isDigit))             // any Unicode digit
def unicodeUpper[_: P] = P(CharPred(_.isUpper))             // uppercase letter
def unicodeLower[_: P] = P(CharPred(_.isLower))             // lowercase letter
def unicodeWhitespace[_: P] = P(CharPred(_.isWhitespace))   // any whitespace

// Caution: CharPred is slower than CharIn. Use CharIn when possible.
// For ASCII-only parsing, prefer CharIn("a-z") over CharPred(_.isLetter)
```

### Multi-Character Alternatives

```scala
// StringIn for keyword-style alternatives (faster than chained |)
def keyword[_: P] = P(StringIn("if", "else", "while", "for", "match"))

// Note: StringIn tries alternatives in order. For overlapping prefixes,
// put longer strings first:
def operator[_: P] = P(StringIn("===", "!==", "==", "!=", "="))
```

---

## Parsing Numbers

### Integer

```scala
def integer[_: P]: P[Int] = P(
  CharIn("0-9").rep(1).!
).map(_.toInt)

// Non-leading-zero integer
def strictInteger[_: P]: P[Int] = P(
  ("0" | CharIn("1-9") ~ CharIn("0-9").rep).!
).map(_.toInt)
```

### Signed Integer

```scala
def signedInt[_: P]: P[Int] = P(
  ("-".? ~ CharIn("0-9").rep(1)).!
).map(_.toInt)
```

### Floating Point

```scala
def float[_: P]: P[Double] = P(
  ("-".? ~ CharIn("0-9").rep(1) ~ "." ~ CharIn("0-9").rep(1)).!
).map(_.toDouble)

// Optional fractional part
def number[_: P]: P[Double] = P(
  ("-".? ~ CharIn("0-9").rep(1) ~ ("." ~ CharIn("0-9").rep(1)).?).!
).map(_.toDouble)
```

### Scientific Notation

```scala
def scientific[_: P]: P[Double] = P(
  ("-".? ~ CharIn("0-9").rep(1) ~ ("." ~ CharIn("0-9").rep(1)).? ~
    CharIn("eE") ~ CharIn("+\\-").? ~ CharIn("0-9").rep(1)).!
).map(_.toDouble)

// Matches: "1.5e10", "-2.3E-5", "42e3", "1E+2"
```

### Hexadecimal / Binary / Octal

```scala
def hex[_: P]: P[Int] = P("0x" ~/ CharIn("0-9a-fA-F").rep(1)).!
  .map(s => Integer.parseInt(s.stripPrefix("0x"), 16))

def binary[_: P]: P[Int] = P("0b" ~/ CharIn("01").rep(1)).!
  .map(s => Integer.parseInt(s.stripPrefix("0b"), 2))

def octal[_: P]: P[Int] = P("0o" ~/ CharIn("0-7").rep(1)).!
  .map(s => Integer.parseInt(s.stripPrefix("0o"), 8))
```

---

## Parsing Strings

### Basic Quoted String

```scala
def simpleString[_: P]: P[String] = P(
  "\"" ~/ CharsWhile(_ != '"').! ~/ "\""
)
```

### String with Escape Sequences

```scala
def escapedChar[_: P]: P[String] = P(
  "\\" ~/ (
    "n".map(_ => "\n") |
    "t".map(_ => "\t") |
    "r".map(_ => "\r") |
    "\"".map(_ => "\"") |
    "\\".map(_ => "\\") |
    "/".map(_ => "/")
  )
)

def stringContent[_: P]: P[String] = P(
  (escapedChar | CharsWhile(c => c != '"' && c != '\\')).rep.!
).map(_.toString)  // Note: this captures raw; proper impl needs accumulation

// Better approach — accumulate parts
def stringLiteral[_: P]: P[String] = P(
  "\"" ~/ (escapedChar | CharsWhile(c => c != '"' && c != '\\').!).rep ~ "\""
).map(_.mkString)
```

### Multi-Line Strings (Triple-Quoted)

```scala
def multiLineString[_: P]: P[String] = P(
  "\"\"\"" ~/ (!"\"\"\"" ~ AnyChar).rep.! ~ "\"\"\""
)
// Matches: """hello
// world"""
```

### Raw Strings (No Escape Processing)

```scala
def rawString[_: P]: P[String] = P(
  "`" ~/ CharsWhile(_ != '`').! ~/ "`"
)
// Matches: `C:\Users\name\file.txt`
```

---

## Common Parser Patterns

### Whitespace-Eating Wrapper

```scala
// Wrap any parser to trim surrounding whitespace
def trimmed[_: P, T](p: => P[T]): P[T] = P(CharIn(" \t").rep ~ p ~ CharIn(" \t").rep)

// Usage
def token[_: P] = P(trimmed(CharIn("a-z").rep(1)).!)
```

### Comment Handling

```scala
// Single-line comment
def lineComment[_: P]: P[Unit] = P("//" ~ CharsWhile(_ != '\n'))

// Block comment (non-nested)
def blockComment[_: P]: P[Unit] = P("/*" ~ (!"*/" ~ AnyChar).rep ~ "*/")

// Either
def comment[_: P]: P[Unit] = P(lineComment | blockComment)

// Whitespace that skips comments
def ws[_: P]: P[Unit] = P((comment | CharIn(" \t\n\r")).rep)
```

### Shebang Line

```scala
def shebang[_: P]: P[String] = P("#!" ~ CharsWhile(_ != '\n').! ~ "\n".?)
// Parse as the first thing in a script parser
def script[_: P] = P(shebang.? ~ statement.rep)
```

### Line Continuation

```scala
// Handle backslash-continued lines: "hello \\\nworld" -> "hello world"
def continuedLine[_: P]: P[String] = P(
  (CharsWhile(c => c != '\\' && c != '\n').! ~ ("\\" ~ "\n").?).rep(1)
).map(_.mkString)
```

### Delimited Block

```scala
// Parse a block delimited by start/end tokens
def block[_: P](start: String, end: String): P[String] = P(
  start ~/ (!end ~ AnyChar).rep.! ~/ end
)

// Usage: block("${", "}") for interpolation, block("<!--", "-->") for HTML comments
```

### Key-Value Pairs with Flexible Whitespace

```scala
def kvPair[_: P]: P[(String, String)] = P(
  CharIn("a-zA-Z_").rep(1).! ~ CharIn(" \t").rep ~ "=" ~ CharIn(" \t").rep ~
    (CharsWhile(c => c != '\n' && c != '#').!).map(_.trim)
)

def config[_: P]: P[Map[String, String]] = P(
  (kvPair ~ CharIn(" \t\n\r").rep).rep
).map(_.toMap)
```

### Identifier with Reserved Word Exclusion

```scala
val reserved = Set("if", "else", "while", "for", "match", "def", "val", "var")

def identifier[_: P]: P[String] = P(
  (CharIn("a-zA-Z_") ~ CharIn("a-zA-Z0-9_").rep).!
).filter(!reserved.contains(_))
// .filter keeps the parse success but fails if the predicate returns false
```
