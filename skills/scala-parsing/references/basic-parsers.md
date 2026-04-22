# Basic Parser Reference

Complete API reference for FastParse basic combinators.

## Parser Construction

### Literal Strings

```scala
def wordParser[_: P] = P("hello")
```

### Sequential Composition (~)

```scala
// Sequence two parsers
def pair[_: P] = P("hello" ~ "world")

// With cut (commits to this branch)
def pairCut[_: P] = P("hello" ~/ "world")
```

### Alternative Composition (|)

```scala
def either[_: P] = P("hello" | "hi" | "hey")
```

## Repetition

```scala
// Zero or more
" ".rep

// One or more
" ".rep(1)

// Exact count
" ".rep(3)

// With separator
"item".rep(sep = "," ~/)

// With bounds
" ".rep(0, 5)
```

## Character Matching

```scala
// Character in range
CharIn("0-9")
CharIn("a-z")
CharIn("A-Z")

// Character by predicate
CharPred(_.isLetter)
CharPred(!_.isDigit)

// Characters while in set
CharsWhileIn("0-9")
CharsWhileIn(!"\"")
```

## Capture and Transform

```scala
// Capture matched string
P(CharIn("a-z").rep(1)).!

// Transform captured value
P(CharIn("0-9").rep(1)).!.map(_.toInt)

// Map to case class
P(name ~ ":" ~ age).map { case (n, a) => Person(n, a) }
```

## Optional

```scala
// Optional match
" ".?

// With default
" ".?.map(_.getOrElse(""))
```

## End of Input

```scala
// Assert end of input
def complete[_: P] = P(myParser ~ End)
```

## Parse Entry Point

```scala
// Parse from string
fastparse.parse("input", myParser(_))

// Returns Parsed.Success or Parsed.Failure
result match {
  case Parsed.Success(value, index) => ???
  case Parsed.Failure(label, index, extra) => ???
}
```
