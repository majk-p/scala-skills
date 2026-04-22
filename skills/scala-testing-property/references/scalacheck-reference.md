# ScalaCheck API Reference

Exhaustive patterns for ScalaCheck property-based testing: generators, combinators, sized generation, shrinking, the Commands API for stateful testing, and test execution configuration. Supplements the main skill with deeper API coverage.

## Generator Combinators

### Filtering and Constraints

```scala
import org.scalacheck.Gen
import org.scalacheck.Arbitrary.arbitrary

// suchThat — post-condition filter (discards non-matching values)
val evenInt = arbitrary[Int].suchThat(_ % 2 == 0)

// retryUntil — retry generation until condition met
val safeEven = Gen.choose(0, 100).retryUntil(_ % 2 == 0)

// filter — discard non-matching (can be slow)
val positives = arbitrary[Int].filter(_ > 0)

// map — transform generated values
val squares = Gen.choose(0, 50).map(x => x * x)
```

### Building Complex Generators

```scala
// flatMap via for-comprehension with dependencies
val genSorted = for {
  n <- Gen.choose(1, 20)
  base <- Gen.choose(0, 100)
  list <- Gen.listOfN(n, Gen.choose(base, base + 50))
} yield list.sorted

// zip — combine generators in parallel
val genPair = Gen.choose(0, 10).zip(Gen.choose(0, 10))

// sequence — Gen[List[A]] from List[Gen[A]]
val gens: List[Gen[Int]] = (1 to 5).map(_ => Gen.choose(0, 100)).toList
val genList: Gen[List[Int]] = Gen.sequence(gens)
```

## Sized Generators

ScalaCheck controls test data size via an implicit `Gen.Parameters` that tracks a `size` value (default 0–100).

```scala
// Gen.sized — access current size
val genSizedList = Gen.sized { size =>
  Gen.listOfN(size, Gen.alphaChar)
}

// Gen.resize — override size for a sub-generator
val genSmall = Gen.resize(5, Gen.listOf(Gen.alphaStr))

// Practical: bounded recursion
def genTree[A](implicit arbA: Arbitrary[A]): Gen[Tree[A]] =
  Gen.sized { size =>
    if (size <= 1) arbA.arbitrary.map(Leaf(_))
    else Gen.resize(size / 2, Gen.oneOf(
      arbA.arbitrary.map(Leaf(_)),
      for {
        l <- genTree[A]
        r <- genTree[A]
      } yield Branch(l, r)
    ))
  }
```

## Recursive Data Types

```scala
sealed abstract class Json
case class JsonStr(s: String) extends Json
case class JsonNum(n: Double) extends Json
case class JsonArr(items: List[Json]) extends Json
case class JsonObj(fields: Map[String, Json]) extends Json

// Gen.lzy — lazy evaluation prevents infinite recursion
val genJson: Gen[Json] = Gen.lzy {
  Gen.sized { size =>
    if (size <= 0) Gen.oneOf(
      Gen.alphaStr.map(JsonStr(_)),
      Gen.choose(0.0, 1000.0).map(JsonNum(_))
    )
    else Gen.frequency(
      (2, Gen.alphaStr.map(JsonStr(_))),
      (2, Gen.choose(0.0, 1000.0).map(JsonNum(_))),
      (1, Gen.resize(size - 1, Gen.listOf(genJson)).map(JsonArr(_))),
      (1, Gen.resize(size - 1, for {
        keys  <- Gen.listOf(Gen.alphaStr)
        vals  <- Gen.listOfN(keys.length, genJson)
      } yield JsonObj(keys.zip(vals).toMap)))
    )
  }
}
```

## Property Combinators (Detailed)

```scala
import org.scalacheck.Prop.{forAll, all, atLeastOne, BooleanOperators}

// ==> implication (discards test case when left is false)
val propPositive = forAll { (n: Int) =>
  (n > 0) ==> (math.sqrt(n) > 0)
}

// && combine two properties (both must hold)
// || either property holds
// == both true or both false

// all — N-ary conjunction
val propAll = all(p1, p2, p3)

// atLeastOne — N-ary disjunction
val propAny = atLeastOne(p1, p2, p3)

// whenever — alternative implication syntax
import org.scalacheck.Prop.whenever
val propWhenever = forAll { (n: Int) =>
  whenever(n > 0) {
    1.0 / n > 0
  }
}
```

## Advanced Shrinking

When a property fails, ScalaCheck minimizes the failing input.

### Custom Shrink Instances

```scala
import org.scalacheck.Shrink

// Derive from existing shrinkers
case class UserId(id: Int)
implicit val shrinkUserId: Shrink[UserId] =
  Shrink.shrinkIntegral.map(UserId(_))

// Container shrinking
implicit val shrinkIntList: Shrink[List[Int]] =
  Shrink.shrinkContainer[List, Int]

// Manual shrink stream
implicit val shrinkRange: Shrink[Range] = Shrink { r =>
  Shrink.shrinkInt(r.start).flatMap { s =>
    Shrink.shrinkInt(r.end).map(e => Range(s, e))
  }
}
```

### Controlling Shrink Behavior

```scala
// Disable shrinking entirely for a type
implicit val noShrinkExpensive: Shrink[ExpensiveType] = Shrink.shrinkAny

// Disable shrinking per-property (MUnit)
property("no shrink") {
  forAllNoShrink { (l: List[Int]) => l.reverse.reverse == l }
}

// Custom shrink that shrinks toward specific values
implicit val shrinkTowardZero: Shrink[Int] = Shrink { n =>
  if (n == 0) Stream.empty
  else Stream.iterate(n / 2)(_ / 2).takeWhile(_ != 0) :+ 0
}
```

## Error Handling in Properties

```scala
import org.scalacheck.Prop.{forAll, exception, throws}

// Expect an exception
val propThrows = forAll { (s: String) =>
  throws(classOf[NumberFormatException])(Integer.parseInt(s))
}

// Wrap exceptions safely
val propSafe = forAll { (n: Int) =>
  exception(_ => true)(dangerousComputation(n))
}

// Property failure investigation with collected values
val propDebug = forAll { (n: Int) =>
  val result = someFunction(n)
  (result >= 0) :| s"result=$result for n=$n" &&
  (result < 100) :| s"result too large: $result"
}

// collect — gather statistics about generated values
import org.scalacheck.Prop.collect
val propStats = forAll { (l: List[Int]) =>
  collect(l.length, l.isEmpty) {
    l.reverse.reverse == l
  }
}
```

## Stateful Testing — Commands API

The Commands API tests stateful systems by generating command sequences and verifying invariants.

```scala
import org.scalacheck.Prop.forAll
import org.scalacheck.commands.Commands

object CounterCommands extends Commands {
  // SUT — the system under test
  case class Counter(var n: Int) {
    def inc(): Unit = n += 1
    def dec(): Unit = n -= 1
    def get: Int = n
  }

  // Abstract state model
  case class State(count: Int)

  // Concrete SUT instance
  override type Sut = Counter
  override def canCreateNewSut(newState: State,
    initSuts: Traversable[State],
    runningSuts: Traversable[Counter]) = true
  override def newSut(state: State): Counter = Counter(state.count)
  override def destroySut(sut: Counter): Unit = ()

  // Initial state
  override def initialPreCondition(state: State): Boolean = true
  override def genInitialState: Gen[State] = Gen.const(State(0))

  // Define commands
  case object Inc extends Command {
    type Result = Unit
    def run(sut: Counter): Unit = sut.inc()
    def nextState(state: State): State = state.copy(count = state.count + 1)
    def preCondition(state: State): Boolean = true
    def postCondition(state: State, result: Result): Prop =
      state.count >= 0
  }

  case object Dec extends Command {
    type Result = Unit
    def run(sut: Counter): Unit = sut.dec()
    def nextState(state: State): State = state.copy(count = state.count - 1)
    def preCondition(state: State): Boolean = true
    def postCondition(state: State, result: Result): Prop =
      state.count >= 0 || true
  }

  case object Get extends Command {
    type Result = Int
    def run(sut: Counter): Int = sut.get
    def nextState(state: State): State = state
    def preCondition(state: State): Boolean = true
    def postCondition(state: State, result: Result): Prop =
      result == state.count
  }

  // Generate command sequences
  override def genCommand(state: State): Gen[Command] =
    Gen.oneOf(Inc, Dec, Get)
}
```

### Running Commands

```scala
// In a test suite
property("counter commands") {
  CounterCommands.property()
}

// With custom parameters
property("counter with params") {
  CounterCommands.property(Test.Parameters.default
    .withMinSuccessfulTests(50)
    .withMaxDiscardRatio(10))
}
```

## Test Execution and Parameters

```scala
import org.scalacheck.Test.{Parameters, Callback, Result}

val params = Parameters.default
  .withMinSuccessfulTests(200)    // default: 100
  .withMinSize(0)                 // smallest generated size
  .withMaxSize(100)               // largest generated size
  .withMaxDiscardRatio(5)         // max discarded / successful ratio
  .withWorkers(4)                 // parallel workers
  .withTestCallback(new Callback {
    override def onTestResult(name: String, result: Result): Unit = {
      if (!result.passed) println(s"FAILED: $name — ${result.status}")
    }
    override def onPropEval(name: String, threads: Int,
      succeeded: Int, discarded: Int): Unit = {
      println(s"$name: $succeeded passed, $discarded discarded")
    }
  })
```

### ScalaCheck Properties Runner

```scala
import org.scalacheck.Test

// Run a standalone property
val result = Test.check(params)(myProperty)
result.passed  // Boolean

// Run a Properties object
Test.checkProperties(params)(MyPropertiesSpec)
```

## Handling Discarded Tests

```scala
// Problem: too many discards from ==> or filter
val propBad = forAll { (n: Int) =>
  (n > 0 && n < 10) ==> (n * 2 < 20)  // discards ~97% of cases
}

// Solution: use targeted generators
val propGood = forAll(Gen.choose(1, 9)) { n =>
  n * 2 < 20
}

// Adjust discard ratio in parameters
val tolerantParams = Parameters.default.withMaxDiscardRatio(20)
```

## Generator Quick Reference

| Factory | Description |
|---|---|
| `Gen.const(x)` | Always generates `x` |
| `Gen.choose(min, max)` | Random number in range |
| `Gen.oneOf(a, b, c)` | Random element |
| `Gen.oneOf(seq)` | Random element from collection |
| `Gen.frequency((w1,g1), ...)` | Weighted random choice |
| `Gen.alphaChar` | Random letter |
| `Gen.alphaStr` | Random letter string |
| `Gen.numChar` | Random digit character |
| `Gen.alphaNumStr` | Alphanumeric string |
| `Gen.identifier` | Valid Scala identifier |
| `Gen.uuid` | Random UUID |
| `Gen.posNum[T]` | Positive number |
| `Gen.negNum[T]` | Negative number |
| `Gen.listOf(g)` | Random-length list |
| `Gen.nonEmptyListOf(g)` | Non-empty random-length list |
| `Gen.listOfN(n, g)` | Fixed-length list |
| `Gen.mapOf(g)` | Random map from (K,V) gen |
| `Gen.someOf(seq)` | Random subset |
| `Gen.pick(n, seq)` | Pick n distinct elements |
