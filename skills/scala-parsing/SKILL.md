---
name: scala-parsing
description: Use this skill when implementing parsers for structured text or DSLs in Scala using FastParse. Covers parser combinators, sequential and alternative parsing, repetition, capturing values, recursive parsers, error handling with cuts, JSON/CSV/expression parsing, memoization, performance optimization, and complex DSL implementation. Trigger when the user mentions parsing, parsers, DSL implementation, text processing, FastParse, or needs to parse custom data formats.
---

# Parser Combinators with FastParse

FastParse is a high-performance parser combinator library for Scala that enables declarative parser construction with excellent error reporting. Parsers are values that compose — you build small parsers and combine them into larger ones.

## Quick Start

```scala
import fastparse._
import fastparse.NoWhitespace._

// Simple literal parser
def helloParser[_: P] = P("hello")

val result = fastparse.parse("hello world", helloParser(_))
// result: Parsed.Success("hello", 5)
```

## Core Combinators

### Sequential Parsing

```scala
// Parse two strings in sequence
def helloWorldParser[_: P] = P("hello" ~ "world")

// With explicit space
def helloSpaceWorldParser[_: P] = P("hello" ~ " " ~ "world")
```

### Alternative Parsing

```scala
// Parse either "hello" or "hi"
def greetingParser[_: P] = P("hello" | "hi")
```

### Repetition

```scala
// Zero or more
def spacesParser[_: P] = P(" ".rep)

// One or more
def spaces1Parser[_: P] = P(" ".rep(1))

// Exact count
def threeDigitsParser[_: P] = P(CharIn("0-9").rep(3))
```

### Character Classes

```scala
// Single character by predicate
def letterParser[_: P] = P(CharPred(_.isLetter))

// Character in set/range
def digitParser[_: P] = P(CharIn("0-9"))
def lowercaseParser[_: P] = P(CharIn("a-z"))

// Character not matching
def notDigitParser[_: P] = P(CharPred(!_.isDigit))
```

### Capturing Values

```scala
// Capture the matched string with .!
def nameParser[_: P] = P(CharIn("a-z").rep(1)).!

val result = fastparse.parse("alice", nameParser(_))
// Success("alice", 5)
```

### Optional Parsing

```scala
def optionalSpaceParser[_: P] = P("hello" ~ " ".? ~ "world")
```

### Transformations

```scala
// Convert captured string to domain type with .map
def numberParser[_: P] = P(CharIn("0-9").rep(1)).!.map(_.toInt)

val result = fastparse.parse("42", numberParser(_))
// Success(42, 2)
```

## Building Complex Parsers

### Parsing Structured Data

```scala
def keyValueParser[_: P] = P(CharIn("a-z").rep(1).! ~ "=" ~ CharIn("a-z").rep(1).!)

def configParser[_: P] = P(keyValueParser.rep(sep = "," ~/))

val result = fastparse.parse("name=alice,age=30", configParser(_))
// Success(List(("name", "alice"), ("age", "30")), 18)
```

### Parsing Case Classes

```scala
case class Person(name: String, age: Int)

def personParser[_: P] = P(
  CharIn("a-zA-Z").rep(1).! ~ ":" ~ CharIn("0-9").rep(1).!.map(_.toInt)
).map { case (name, age) => Person(name, age) }

val result = fastparse.parse("alice:30", personParser(_))
// Success(Person("alice", 30), 8)
```

## Recursive Parsers

### Arithmetic Expressions

```scala
sealed trait Expr
case class Num(value: Int) extends Expr
case class Add(left: Expr, right: Expr) extends Expr
case class Mul(left: Expr, right: Expr) extends Expr

def number[_: P]: P[Expr] = P(CharIn("0-9").rep(1)).!.map(s => Num(s.toInt))

def factor[_: P]: P[Expr] = P(number | ("(" ~/ expr ~ ")"))

def term[_: P]: P[Expr] = P(
  factor.rep(1).map {
    case Seq(single) => single
    case factors => factors.reduceLeft(Mul(_, _))
  }
)

def expr[_: P]: P[Expr] = P(
  term.rep(1).map {
    case Seq(single) => single
    case terms => terms.reduceLeft(Add(_, _))
  }
)

def eval(e: Expr): Int = e match {
  case Num(v) => v
  case Add(l, r) => eval(l) + eval(r)
  case Mul(l, r) => eval(l) * eval(r)
}
```

### JSON Parser

```scala
sealed trait JsonValue
case class JsonString(value: String) extends JsonValue
case class JsonNumber(value: Double) extends JsonValue
case class JsonBool(value: Boolean) extends JsonValue
case class JsonNull() extends JsonValue
case class JsonArray(values: List[JsonValue]) extends JsonValue
case class JsonObject(fields: Map[String, JsonValue]) extends JsonValue

def ws[_: P]: P[Unit] = P(" ".rep | "\n".rep | "\t".rep)

def jsonString[_: P] = P("\"" ~/ CharsWhileIn(!"\"").! ~/ "\"").map(JsonString)

def jsonNumber[_: P] = P(
  ("-".? ~ CharIn("0-9").rep(1) ~ ("." ~ CharIn("0-9").rep(1)).?).!
).map(s => JsonNumber(s.toDouble))

def jsonBool[_: P] = P(("true" | "false").!.map(s => JsonBool(s.toBoolean)))

def jsonNull[_: P] = P("null").map(_ => JsonNull())

def jsonArray[_: P]: P[JsonArray] = P("[" ~/ jsonValue.rep(sep = "," ~/) ~ "]").map(JsonArray)

def jsonField[_: P]: P[(String, JsonValue)] = P(jsonString.map(_.value) ~ ":" ~/ jsonValue)

def jsonObject[_: P]: P[JsonObject] = P(
  "{" ~/ jsonField.rep(sep = "," ~/) ~ "}"
).map(fields => JsonObject(fields.toMap))

def jsonValue[_: P]: P[JsonValue] = P(
  ws ~ (jsonString | jsonNumber | jsonBool | jsonNull | jsonArray | jsonObject) ~ ws
)

def parseJson[_: P]: P[JsonValue] = P(jsonValue ~ End)
```

## CSV Parser

```scala
def csvCell[_: P] = P(
  CharsWhileIn(!",\n").! |
  "\"" ~/ CharsWhileIn(!"\"").! ~/ "\""
)

def csvRow[_: P] = P(csvCell.rep(sep = "," ~/))

def csvFile[_: P] = P(csvRow.rep(sep = "\n" ~/) ~ End)
```

## Error Handling

### Cuts for Better Error Messages

```scala
// Without cut — vague error at first alternative
P("hello" ~ ("world" | "universe"))
// On "hellox": "expected world" or "expected universe" at index 5

// With cut (~/) — commits after "hello", better error location
P("hello" ~/ ("world" | "universe"))
// On "hellox": clear error at index 5 after committed "hello"
```

### Custom Error Messages

```scala
def parser[_: P]: P[String] =
  P("hello" | Fail("Expected 'hello'"))
```

### Debugging with Log

```scala
def complexParser[_: P] =
  P(
    "hello".log("prefix") ~
    " ".log("space") ~
    "world".log("suffix")
  )
// Output shows each step's position and success/failure
```

## Common Gotchas

### Left Recursion

```scala
// WON'T WORK — infinite recursion
def expr[_: P] = P(expr ~ "+" ~ expr | number)

// WORKS — factorize into non-left-recursive rules
def expr[_: P] = P(term ~ ("+" ~ term).*)
def term[_: P] = P(factor ~ ("*" ~ factor).*)
def factor[_: P] = P(number | "(" ~/ expr ~ ")")
```

### Whitespace Modes

```scala
import fastparse.NoWhitespace._
// Exact match mode — P("hello" ~ "world") matches "helloworld"

import fastparse._
// Default mode — whitespace implicitly handled between tokens
```

## Performance Tips

1. Use `CharIn("a-z")` over `CharPred(_.isLetter)` — character sets are faster
2. Use cuts (`~/`) to commit to choices and avoid unnecessary backtracking
3. Use `NoWhitespace` mode for better performance when whitespace is explicit
4. Profile with `.log()` to identify bottlenecks

## Best Practices

1. Use cuts (`~/`) after committing to a parse choice for better error messages
2. Start with small parsers and combine them incrementally
3. Capture with `.!` and transform with `.map` to build domain types
4. Factorize left-recursive grammars into non-left-recursive components
5. Handle whitespace explicitly or use `NoWhitespace` mode
6. Test edge cases: empty input, partial matches, malformed input

## Dependencies

```scala
// check for latest version
libraryDependencies += "com.lihaoyi" %% "fastparse" % "3.1.+"
```

## Related Skills

- **scala-lang** — for Scala syntax and language features used in parser definitions
- **scala-code-generation** — when parsing feeds into code generation pipelines
- **scala-testing-property** — for property-based testing of parser correctness

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/basic-parsers.md** — Complete FastParse combinator API: all combinators, character classes, capture, transformation, repetition options, common patterns
- **references/advanced-parsers.md** — Memoization, conditional parsing, complex DSL implementation, AST construction, performance profiling, integration patterns
