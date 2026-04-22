# Advanced Parser Reference

Exhaustive reference for advanced FastParse patterns: memoization, left-recursion elimination,
error recovery, testing, real-world DSLs, performance profiling, and integration with effect systems.

---

## Memoization (Corrected)

### The Problem with Naive Lazy Val

The previous version of this file showed `lazy val expr = P(expr ~ "+" ~ expr | ...)` — this
still causes infinite recursion because the `lazy val` only delays initialization, not evaluation
at parse time. **Memoization in FastParse is automatic** — the parser caches results at each
position internally.

### When Memoization Matters

FastParse automatically memoizes during a single parse run. You don't need `lazy val` for
recursion. The factorization pattern (expr → term → factor) already avoids exponential
backtracking:

```scala
// This is already efficient — FastParse memoizes sub-results
def expr[_: P]: P[Expr] = P(term ~ ("+" ~/ term).rep).map {
  case (first, rest) => rest.foldLeft(first)(Add(_, _))
}
def term[_: P]: P[Expr] = P(factor ~ ("*" ~/ factor).rep).map {
  case (first, rest) => rest.foldLeft(first)(Mul(_, _))
}
def factor[_: P]: P[Expr] = P(number | "(" ~/ expr ~ ")")
```

### Manual Memoization with Index-Based Caching

For grammars where the same sub-parser is invoked at the same position many times across
different parse attempts (e.g., in an IDE re-parsing on every keystroke), cache externally:

```scala
import scala.collection.mutable

def memoizingParser[T](inner: => P[T]): P[T] = {
  val cache = mutable.Map[Int, Parsed[T]]()
  new P[T] {
    def parse(ctx: ParsingRun[_]): Parsed[T] = {
      cache.get(ctx.index) match {
        case Some(result) => result
        case None =>
          val result = inner.parse(ctx)
          cache(ctx.index) = result
          result
      }
    }
  }
}
```

---

## Left Recursion Elimination

### The Problem

Left-recursive grammars cause infinite recursion in top-down parsers:

```
// Grammar (left-recursive — causes stack overflow):
expr = expr "+" term | term
term = term "*" factor | factor
factor = number | "(" expr ")"
```

### Standard Solution: Factor into Iterative Patterns

Transform `A = A op B | B` into `A = B (op B)*`:

```scala
sealed trait Expr
case class Num(value: Double) extends Expr
case class BinOp(op: String, left: Expr, right: Expr) extends Expr

def number[_: P]: P[Expr] = P(CharIn("0-9").rep(1)).!.map(s => Num(s.toDouble))

def factor[_: P]: P[Expr] = P(number | "(" ~/ expr ~ ")")

def term[_: P]: P[Expr] = P(factor ~ ("*" ~/ factor | "/" ~/ factor).rep).map {
  case (first, rest) =>
    rest.foldLeft(first) { case (acc, opOrExpr) =>
      // opOrExpr is the right-side factor; we need to capture the operator too
      acc // simplified — see full pattern below
    }
}
```

### Complete Expression Parser with Captured Operators

```scala
sealed trait Expr
case class Num(v: Double) extends Expr
case class BinOp(op: String, l: Expr, r: Expr) extends Expr
case class UnaryOp(op: String, e: Expr) extends Expr

def number[_: P]: P[Expr] = P(CharIn("0-9").rep(1) ~ ("." ~ CharIn("0-9").rep).?).!
  .map(s => Num(s.toDouble))

def unary[_: P]: P[Expr] = P(
  ("-".! ~ unary).map { case (op, e) => UnaryOp(op, e) } |
    "+" ~ factor |
    factor
)

def factor[_: P]: P[Expr] = P(number | "(" ~/ expr ~ ")")

// Each precedence level captures (operator, operand) pairs
def term[_: P]: P[Expr] = P(unary ~ (CharIn("*/").! ~/ unary).rep).map {
  case (first, rest) => rest.foldLeft(first) { case (l, (op, r)) => BinOp(op, l, r) }
}

def expr[_: P]: P[Expr] = P(term ~ (CharIn("+\\-").! ~/ term).rep).map {
  case (first, rest) => rest.foldLeft(first) { case (l, (op, r)) => BinOp(op, l, r) }
}

// For comparison operators (lower precedence than +/-):
def comparison[_: P]: P[Expr] = P(expr ~ (StringIn("==", "!=", "<=", ">=", "<", ">").! ~/ expr).rep).map {
  case (first, rest) => rest.foldLeft(first) { case (l, (op, r)) => BinOp(op, l, r) }
}

// For logical operators (lowest precedence):
def logicAnd[_: P]: P[Expr] = P(comparison ~ ("&&" ~/ comparison).rep).map {
  case (first, rest) => rest.foldLeft(first) { case (l, r) => BinOp("&&", l, r) }
}

def logicOr[_: P]: P[Expr] = P(logicAnd ~ ("||" ~/ logicAnd).rep).map {
  case (first, rest) => rest.foldLeft(first) { case (l, r) => BinOp("||", l, r) }
}
```

### Pratt Parser Approach (Alternative)

For grammars with many precedence levels, a Pratt-style parser is cleaner:

```scala
// Assign precedence values to operators
val prefixOps = Map("-" -> 3, "!" -> 3)
val infixOps = Map(
  "*" -> 5, "/" -> 5,
  "+" -> 4, "-" -> 4,
  "<" -> 3, ">" -> 3, "==" -> 3, "!=" -> 3,
  "&&" -> 2,
  "||" -> 1
)

def prattExpr[_: P](minPrec: Int): P[Expr] = P {
  // Parse primary (number or parenthesized expr)
  val primary = number | "(" ~/ prattExpr(0) ~ ")"

  // Parse optional prefix
  val prefixResult = (CharIn("+\\-!").!.? ~ primary).map {
    case (Some(op), e) => if (op == "-") UnaryOp(op, e) else e
    case (None, e)     => e
  }

  // Parse infix operators with precedence climbing
  def loop(left: Expr): P[Expr] = P {
    val opStr = StringIn("==", "!=", "<=", ">=", "&&", "||", "+", "-", "*", "/", "<", ">").!
    opStr.flatMap { op =>
      val prec = infixOps.getOrElse(op, 0)
      if (prec < minPrec) Fail
      else {
        val nextMinPrec = prec + 1 // left-associative; use prec for right-assoc
        prattExpr(nextMinPrec).map(right => BinOp(op, left, right)).flatMap(loop)
      }
    } | Pass(left)
  }

  prefixResult.flatMap(loop)
}

// Entry point
def expression[_: P]: P[Expr] = P(prattExpr(0))
```

---

## Error Recovery

### Partial Parsing (Don't Consume Entire Input)

```scala
// Parse as much as possible, return the index where parsing stopped
def partialParse(input: String): (Option[Result], Int) = {
  fastparse.parse(input, myParser(_)) match {
    case Parsed.Success(value, idx) => (Some(value), idx)
    case f: Parsed.Failure          => (None, f.index)
  }
}
```

### Continuing After Errors

```scala
// Skip to the next statement boundary and continue parsing
def recoverStatement[_: P]: P[Option[Statement]] = P(
  (statement.map(Some(_)) | (CharsWhile(c => c != ';' && c != '\n') ~ (";" | "\n")).map(_ => None))
)

def recoverableProgram[_: P]: P[List[Statement]] = P(
  recoverStatement.rep.map(_.flatten.toList)
)
```

### Collecting Multiple Errors

```scala
case class ParseError(position: Int, message: String, line: Int, column: Int)

def parseWithRecovery(input: String): (List[Statement], List[ParseError]) = {
  val errors = List.newBuilder[ParseError]
  val statements = List.newBuilder[Statement]
  var remaining = input
  var offset = 0

  while (remaining.nonEmpty) {
    fastparse.parse(remaining, statement(_)) match {
      case Parsed.Success(stmt, idx) =>
        statements += stmt
        remaining = remaining.substring(idx)
        offset += idx
      case f: Parsed.Failure =>
        val line = input.substring(0, f.index).count(_ == '\n') + 1
        val col = input.substring(0, f.index).lastIndexOf('\n') match {
          case -1  => f.index + 1
          case idx => f.index - idx
        }
        errors += ParseError(f.index, f.trace().label, line, col)
        // Skip to next statement boundary
        val skipTo = remaining.indexWhere(c => c == ';' || c == '\n')
        if (skipTo >= 0) {
          remaining = remaining.substring(skipTo + 1)
          offset += skipTo + 1
        } else {
          remaining = ""
        }
    }
  }

  (statements.result(), errors.result())
}
```

### Error-Tolerant Parsing for IDEs

```scala
// Allow incomplete expressions for IDE autocomplete
def tolerantExpr[_: P]: P[Option[Expr]] = P(
  (expr.map(Some(_)) | Pass(None)) // Accept partial or empty input
)

def tolerantStatement[_: P]: P[Option[Statement]] = P(
  statement.map(Some(_)) |
    // Tolerate missing semicolons, incomplete expressions
    (identifier ~ "=" ~/ tolerantExpr ~ ";".?).map {
      case (name, Some(e)) => Some(Assignment(name, e))
      case (name, None)    => Some(Assignment(name, Num(0))) // placeholder
    }
)
```

---

## Testing Parsers

### Unit Tests for Parsers

```scala
// Using munit (or any test framework)
class ParserTests extends munit.FunSuite {

  def parse[T](input: String, p: P[_] => P[T]): Parsed[T] =
    fastparse.parse(input, p(_))

  test("number parser accepts positive integers") {
    assertEquals(parse("42", number(_)), Parsed.Success(Num(42), 2))
  }

  test("number parser rejects empty input") {
    assert(parse("", number(_)).isInstanceOf[Parsed.Failure])
  }

  test("expression parser handles addition") {
    parse("1+2", expr(_)) match {
      case Parsed.Success(BinOp("+", Num(1), Num(2)), _) => // pass
      case other => fail(s"Unexpected: $other")
    }
  }

  test("expression parser respects precedence") {
    parse("2+3*4", expr(_)) match {
      case Parsed.Success(BinOp("+", Num(2), BinOp("*", Num(3), Num(4))), _) => // pass
      case other => fail(s"Unexpected: $other")
    }
  }
}
```

### Testing Error Messages

```scala
  test("missing closing paren gives clear error") {
    parse("(1+2", expr(_)) match {
      case f: Parsed.Failure =>
        assert(f.trace().label.contains(")"))
      case _: Parsed.Success[_] => fail("Should have failed")
    }
  }

  test("error position is accurate") {
    parse("hello xorld", keywordParser(_)) match {
      case f: Parsed.Failure =>
        assertEquals(f.index, 6) // points to 'x' not 'h'
      case _: Parsed.Success[_] => fail("Should have failed")
    }
  }
}
```

### Property-Based Testing of Parsers

```scala
import org.scalacheck.Prop.forAll
import org.scalacheck.Gen

class ParserPropertyTests extends munit.ScalaCheckSuite {

  val intGen: Gen[Int] = Gen.choose(0, 10000)
  val exprGen: Gen[String] = Gen.oneOf(
    intGen.map(_.toString),
    Gen.binaryOp(exprGen, exprGen, Gen.oneOf("+", "-", "*", "/"))
  )

  property("number parser round-trips") {
    forAll(intGen) { n: Int =>
      parse(n.toString, number(_)) match {
        case Parsed.Success(Num(v), _) => v == n
        case _ => false
      }
    }
  }

  property("parsed expressions evaluate consistently") {
    forAll(intGen, intGen) { (a: Int, b: Int) =>
      val input = s"$a+$b"
      parse(input, expr(_)) match {
        case Parsed.Success(e, _) => eval(e) == a + b
        case _ => false
      }
    }
  }
}
```

---

## Real-World DSL: SQL WHERE Clause Parser

### Grammar

```
whereExpr = orExpr
orExpr    = andExpr (" OR " andExpr)*
andExpr   = notExpr (" AND " notExpr)*
notExpr   = "NOT" notExpr | comparison
comparison = value op value
op        = "=" | "!=" | "<" | ">" | "<=" | ">=" | "LIKE" | "IN"
value     = identifier | stringLiteral | number | "(" whereExpr ")"
```

### AST Definition

```scala
sealed trait FilterExpr
case class Compare(left: FilterValue, op: String, right: FilterValue) extends FilterExpr
case class And(left: FilterExpr, right: FilterExpr) extends FilterExpr
case class Or(left: FilterExpr, right: FilterExpr) extends FilterExpr
case class Not(expr: FilterExpr) extends FilterExpr
case class In(value: FilterValue, values: List[FilterValue]) extends FilterExpr

sealed trait FilterValue
case class Ident(name: String) extends FilterValue
case class StrVal(value: String) extends FilterValue
case class NumVal(value: Double) extends FilterValue
case class BoolVal(value: Boolean) extends FilterValue
```

### Parser Implementation

```scala
import fastparse._
import fastparse.NoWhitespace._

object SqlFilterParser {

  def ws[_: P] = P(CharIn(" \t").rep)
  def ws1[_: P] = P(CharIn(" \t").rep(1))

  // Values
  def stringLit[_: P]: P[FilterValue] = P(
    "'" ~/ (CharsWhile(_ != '\'') | "''").! ~/ "'"
  ).map(StrVal)

  def numberLit[_: P]: P[FilterValue] = P(
    ("-".? ~ CharIn("0-9").rep(1) ~ ("." ~ CharIn("0-9").rep(1)).?).!
  ).map(s => NumVal(s.toDouble))

  def boolLit[_: P]: P[FilterValue] = P(
    StringIn("true", "false").!
  ).map(s => BoolVal(s.toBoolean))

  def ident[_: P]: P[FilterValue] = P(
    (CharIn("a-zA-Z_") ~ CharIn("a-zA-Z0-9_.").rep).!
  ).map(Ident)

  def value[_: P]: P[FilterValue] = P(stringLit | numberLit | boolLit | ident)

  // Operators
  def compareOp[_: P]: P[String] = P(
    StringIn(">=", "<=", "!=", "<>", "==", "=", "LIKE", "like", "<", ">")
  ).!

  // Comparison
  def comparison[_: P]: P[FilterExpr] = P(
    ws ~ value ~ ws1 ~ compareOp ~ ws1 ~ value ~ ws
  ).map { case (l, op, r) => Compare(l, op.toLowerCase, r) }

  // IN expression
  def inExpr[_: P]: P[FilterExpr] = P(
    ws ~ value ~ ws1 ~ StringIn("IN", "in") ~ ws ~
      "(" ~/ value.rep(1, sep = "," ~/ ws) ~ ")"
  ).map { case (v, values) => In(v, values.toList) }

  // NOT
  def notExpr[_: P]: P[FilterExpr] = P(
    ws ~ (StringIn("NOT", "not") ~/ ws1 ~ notExpr).map(Not) |
      inExpr | comparison | ("(" ~/ orExpr ~ ")")
  )

  // AND
  def andExpr[_: P]: P[FilterExpr] = P(
    notExpr ~ (ws1 ~ StringIn("AND", "and") ~/ ws1 ~ notExpr).rep
  ).map {
    case (first, rest) => rest.foldLeft(first)(And(_, _))
  }

  // OR
  def orExpr[_: P]: P[FilterExpr] = P(
    andExpr ~ (ws1 ~ StringIn("OR", "or") ~/ ws1 ~ andExpr).rep
  ).map {
    case (first, rest) => rest.foldLeft(first)(Or(_, _))
  }

  // Entry point
  def filter[_: P]: P[FilterExpr] = P(ws ~ orExpr ~ ws ~ End)
}

def parseFilter(input: String): Either[String, FilterExpr] =
  fastparse.parse(input, SqlFilterParser.filter(_)) match {
    case Parsed.Success(expr, _) => Right(expr)
    case f: Parsed.Failure       => Left(s"Parse error at ${f.index}: ${f.trace().label}")
  }
```

### Evaluator

```scala
type Row = Map[String, Any]

def evalFilter(expr: FilterExpr)(row: Row): Boolean = expr match {
  case Compare(l, op, r) =>
    val lv = resolveValue(l, row)
    val rv = resolveValue(r, row)
    op match {
      case "="  => lv == rv
      case "!=" => lv != rv
      case "<"  => compareNum(lv, rv) < 0
      case ">"  => compareNum(lv, rv) > 0
      case "<=" => compareNum(lv, rv) <= 0
      case ">=" => compareNum(lv, rv) >= 0
      case "like" => lv.toString.matches(rv.toString.replace("%", ".*").replace("_", "."))
    }
  case And(l, r) => evalFilter(l)(row) && evalFilter(r)(row)
  case Or(l, r)  => evalFilter(l)(row) || evalFilter(r)(row)
  case Not(e)    => !evalFilter(e)(row)
  case In(v, vs) => vs.exists(_.toString == resolveValue(v, row).toString)
}

def resolveValue(v: FilterValue, row: Row): Any = v match {
  case Ident(name) => row.getOrElse(name, throw new NoSuchElementException(name))
  case StrVal(s)   => s
  case NumVal(n)   => n
  case BoolVal(b)  => b
}

def compareNum(a: Any, b: Any): Int = (a, b) match {
  case (a: Number, b: Number) => a.doubleValue.compareTo(b.doubleValue)
  case _                      => a.toString.compareTo(b.toString)
}
```

---

## Performance Profiling

### Using `.log()` for Tracing

```scala
def instrumented[_: P] = P(
  CharIn("a-z").rep(1).!.log("identifier") ~
    ("=".log("equals") | ":".log("colon")) ~
    CharIn("0-9").rep(1).!.log("value")
)
// Console output on parse:
//   +identifier:1:1
//   +identifier:1:1: Success(4)
//   +equals:1:5
//   -equals:1:5: Failure(...)
//   +colon:1:5
//   +colon:1:5: Success(6)
//   +value:1:6
//   +value:1:6: Success(2)
```

### Benchmarking Parser Performance

```scala
// Using JMH (add sbt-jmh plugin)
import java.util.concurrent.TimeUnit
import org.openjdk.jmh.annotations._

@State(Scope.Benchmark)
@BenchmarkMode(Array(Mode.AverageTime))
@OutputTimeUnit(TimeUnit.MILLISECONDS)
class ParserBenchmark {
  @Param(Array("small", "medium", "large"))
  var size: String = _

  var input: String = _

  @Setup
  def setup(): Unit = input = generateInput(size)

  @Benchmark
  def parseJson(): Parsed[JsonValue] =
    fastparse.parse(input, jsonParser(_))
}

// Or simple manual benchmark:
def bench(label: String, input: String, parser: P[_] => P[_], runs: Int = 1000): Unit = {
  // Warm up
  (1 to 50).foreach(_ => fastparse.parse(input, parser(_)))

  val start = System.nanoTime()
  (1 to runs).foreach(_ => fastparse.parse(input, parser(_)))
  val elapsed = (System.nanoTime() - start) / 1e6
  println(s"$label: ${elapsed}ms total, ${elapsed / runs}ms per parse")
}
```

### Optimizing Hot Paths

```scala
// 1. Replace CharPred with CharIn where possible
// Bad:  CharPred(_.isDigit)       — lambda call per char
// Good: CharIn("0-9")             — pre-computed bitset

// 2. Use CharsWhileIn instead of CharIn.rep(1)
// Bad:  CharIn("0-9").rep(1)     — creates rep node, checks per iteration
// Good: CharsWhileIn("0-9")       — single intrinsic call

// 3. Use cuts to avoid backtracking
// Bad:  "if" ~ expr
// Good: "if" ~/ expr              — after "if", don't try alternatives

// 4. Avoid .rep without bounds on unbounded input
// Bad:  AnyChar.rep               — can consume entire input
// Good: (!delimiter ~ AnyChar).rep — stops at delimiter

// 5. Use StringIn for keyword alternatives
// Bad:  "if" | "else" | "while"   — linear scan
// Good: StringIn("if", "else", "while") — optimized trie lookup
```

### Chunk-Based Parsing for Large Inputs

```scala
// For very large files, parse line-by-line or chunk-by-chunk
def parseLargeFile(path: java.nio.file.Path): Iterator[Parsed[Statement]] = {
  scala.io.Source.fromFile(path.toFile).getLines().map { line =>
    fastparse.parse(line, statement(_))
  }
}

// For streaming with fs2 (see Integration Patterns below)
```

---

## Integration Patterns

### Using Parser Output with Cats Effect IO

```scala
import cats.effect.IO
import fastparse._

def parseIO[T](input: String, parser: P[_] => P[T]): IO[T] = IO {
  fastparse.parse(input, parser(_)) match {
    case Parsed.Success(value, _) => value
    case f: Parsed.Failure =>
      throw new ParseError(s"At ${f.index}: ${f.trace().label}")
  }
}

// Usage
def process(input: String): IO[Expr] =
  parseIO(input, expression(_)).map { expr =>
    // Further processing
    eval(expr)
  }
```

### Integrating with fs2 Streams

```scala
import fs2.Stream
import cats.effect.IO

// Parse each line in a stream
def parseStream(lines: Stream[IO, String]): Stream[IO, Statement] =
  lines.mapFilter { line =>
    fastparse.parse(line.trim, statement(_)) match {
      case Parsed.Success(stmt, _) => Some(stmt)
      case _: Parsed.Failure       => None // skip unparseable lines
    }
  }

// Chunk-based streaming parser for structured input
def parseRecords(input: Stream[IO, Byte]): Stream[IO, Record] = {
  def go(chunk: String, rest: Stream[IO, String]): Pull[IO, Record, Unit] = ???
  // Accumulate bytes until a complete record is found, then parse
  input.through(fs2.text.utf8Decode)
    .through(fs2.text.lines)
    .mapFilter { line =>
      fastparse.parse(line, record(_)) match {
        case Parsed.Success(r, _) => Some(r)
        case _                    => None
      }
    }
}
```

### Building a REPL Around a Parser

```scala
def repl(): Unit = {
  val reader = new jline.console.ConsoleReader()
  reader.setPrompt("parser> ")

  var running = true
  while (running) {
    val line = reader.readLine()
    if (line == null || line == ":quit") {
      running = false
    } else if (line.trim.nonEmpty) {
      fastparse.parse(line, replExpr(_)) match {
        case Parsed.Success(value, _) =>
          println(s"Result: ${eval(value)}")
        case f: Parsed.Failure =>
          // Show error with caret pointing to failure position
          val caret = " " * f.index + "^"
          println(s"Error:\n  $line\n  $caret\n  ${f.trace().label}")
      }
    }
  }
}

// Multi-line input for REPL (accumulate until statement is complete)
def replLoop(): Unit = {
  val reader = new jline.console.ConsoleReader()
  val buf = new StringBuilder()
  var depth = 0

  Iterator.continually(reader.readLine(if (buf.isEmpty) "> " else "  ")).takeWhile(_ != null).foreach { line =>
    depth += line.count(_ == '(') - line.count(_ == ')')
    buf ++= line + "\n"
    if (depth <= 0 && buf.toString.trim.nonEmpty) {
      fastparse.parse(buf.toString, statement(_)) match {
        case Parsed.Success(value, _) =>
          println(s"Result: ${eval(value)}")
        case f: Parsed.Failure =>
          println(s"Error: ${f.trace().label}")
      }
      buf.clear()
    }
  }
}
```

### Parsing with Custom Context (Configurable Parsers)

```scala
// Parameterized parser for dialect variations
case class DialectConfig(
  allowTrailingComma: Boolean,
  commentStyle: CommentStyle,
  identifierQuoting: Boolean
)

sealed trait CommentStyle
case object HashComments extends CommentStyle
case object DoubleSlashComments extends CommentStyle
case object BothComments extends CommentStyle

def makeParser(config: DialectConfig) = new {
  def comment[_: P]: P[Unit] = config.commentStyle match {
    case HashComments      => P("#" ~ CharsWhile(_ != '\n'))
    case DoubleSlashComments => P("//" ~ CharsWhile(_ != '\n'))
    case BothComments      => P(("#" | "//") ~ CharsWhile(_ != '\n'))
  }

  def trailingComma[_: P]: P[Unit] = if (config.allowTrailingComma) {
    P(",".? ~ CharIn(" \t\n\r").rep)
  } else {
    P(CharIn(" \t\n\r").rep)
  }

  def identifier[_: P]: P[String] = {
    val base = P(CharIn("a-zA-Z_") ~ CharIn("a-zA-Z0-9_").rep).!
    if (config.identifierQuoting) P(("`" ~/ base ~/ "`") | base) else base
  }
}
```
