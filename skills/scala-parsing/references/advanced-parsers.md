# Advanced Parser Reference

Complete reference for advanced FastParse patterns, performance, and integration.

## Memoization

```scala
// For grammars with repeated sub-parses, use lazy val
lazy val expr: P[String] = P(expr ~ "+" ~ expr | CharIn("0-9"))
```

## Conditional Parsing

```scala
def conditionalParser[_: P](expectSpace: Boolean) =
  P("hello" ~ (if (expectSpace) " " else End))
```

## Complex Syntax Trees

```scala
sealed trait AST
case class Node(value: String, children: List[AST]) extends AST

def tree[_: P]: P[AST] = P(
  CharIn("a-z").!.map(Node(_, Nil)) |
  "(" ~/ tree.rep(sep = " " ~/).map(nodes => Node("group", nodes.toList)) ~ ")"
)
```

## DSL to Domain Model

```scala
case class Command(name: String, args: List[String])

def command[_: P]: P[Command] = P(
  CharIn("a-z").rep(1).! ~ " ".rep(1) ~
  CharIn("a-z").rep(1).!.rep(sep = " " ~/)
).map { case (name, args) => Command(name, args.toList) }
```

## Shape DSL Example

```scala
sealed trait Shape
case class Rectangle(width: Int, height: Int) extends Shape
case class Circle(radius: Int) extends Shape

def rectangle[_: P]: P[Shape] = P(
  "rectangle" ~ " " ~ CharIn("0-9").rep(1).!.map(_.toInt) ~ "x" ~
  CharIn("0-9").rep(1).!.map(_.toInt)
).map { case (w, h) => Rectangle(w, h) }

def circle[_: P]: P[Shape] = P(
  "circle" ~ " " ~ CharIn("0-9").rep(1) ~ "r"
).map(r => Circle(r.toInt))

def shape[_: P]: P[Shape] = P(rectangle | circle)

def shapes[_: P] = P(shape.rep(sep = ","))
```

## Performance Optimization

### Prefer CharIn over CharPred

```scala
// Better — character set (pre-computed)
CharIn("a-z")

// Worse — predicate (evaluated per character)
CharPred(_.isLetter)
```

### Use Cuts to Avoid Backtracking

```scala
// Better — commits to choice after "hello"
P("hello" ~/ ("world" | "universe"))

// Worse — may backtrack unnecessarily
P("hello" ~ ("world" | "universe"))
```

### Use NoWhitespace Mode

```scala
import fastparse.NoWhitespace._
// No implicit whitespace handling — faster parsing
```

### Profile with .log()

```scala
// Debug and identify bottlenecks
"hello".log("prefix") ~ "world".log("suffix")
```

### Prefer Character Sets Over Alternatives

```scala
// Better — single character set
P(CharIn("a-e").rep(1))

// Worse — many alternatives
P(("a" | "b" | "c" | "d" | "e").rep(1))
```

## Integration Patterns

### Parser Returning Typed AST

```scala
sealed trait Expr
case class Literal(value: Int) extends Expr
case class BinOp(op: String, left: Expr, right: Expr) extends Expr

def literal[_: P]: P[Expr] = P(CharIn("0-9").rep(1)).!.map(s => Literal(s.toInt))

def binExpr[_: P]: P[Expr] = P(
  literal ~ (CharIn("+\\-*/").! ~/ literal).rep
).map {
  case (first, rest) =>
    rest.foldLeft(first) { case (acc, (op, right)) => BinOp(op, acc, right) }
}
```

### Composing Parsers from Modules

```scala
object NumberParser {
  def integer[_: P] = P(CharIn("0-9").rep(1)).!.map(_.toInt)
  def decimal[_: P] = P(integer ~ ("." ~/ CharIn("0-9").rep(1)).?).map {
    case (whole, Some(frac)) => s"$whole.$frac".toDouble
    case (whole, None) => whole.toDouble
  }
}

object StringParser {
  def quoted[_: P] = P("\"" ~/ CharsWhileIn(!"\"").! ~/ "\"")
  def unquoted[_: P] = P(CharIn("a-zA-Z0-9_").rep(1)).!
}
```
