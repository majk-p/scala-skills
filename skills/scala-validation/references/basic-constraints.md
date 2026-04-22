# Basic Constraints Reference

Exhaustive reference for all Iron built-in constraints. The main SKILL.md covers the overview and quick-start patterns — this file provides constraint-by-constraint details with full parameter signatures and concrete examples.

## Numeric Constraints

All numeric constraints live in `io.github.iltotore.iron.constraint.numeric.*`.

### Positive

Value must be strictly greater than 0.

```scala
import io.github.iltotore.iron.constraint.numeric.*

type PositiveInt = Int :| Positive
type PositiveLong = Long :| Positive
type PositiveDouble = Double :| Positive

val x: PositiveInt = 5          // OK
val y: PositiveInt = 0          // Compile-time error
val z: PositiveInt = -3         // Compile-time error
```

### Negative

Value must be strictly less than 0.

```scala
type NegativeInt = Int :| Negative
type NegativeDouble = Double :| Negative

val x: NegativeInt = -5         // OK
val y: NegativeInt = 0          // Compile-time error
val z: NegativeInt = 3          // Compile-time error
```

### Greater[V]

Value must be strictly greater than the literal `V`.

```scala
type Age = Int :| Greater[18]
type Temperature = Double :| Greater[0.0]
type Count = Long :| Greater[0L]

val adult: Age = 25             // OK
val child: Age = 10             // Compile-time error
val boundary: Age = 18          // Compile-time error (strictly greater)
```

### Less[V]

Value must be strictly less than the literal `V`.

```scala
type Percentage = Double :| Less[1.0]
type Threshold = Int :| Less[100]
type Limit = Long :| Less[1000L]

val valid: Percentage = 0.99    // OK
val boundary: Percentage = 1.0  // Compile-time error (strictly less)
val over: Percentage = 1.5      // Compile-time error
```

### Interval[V1, V2]

Value must be between V1 and V2, **inclusive** on both ends.

```scala
type Score = Int :| Interval[0, 100]
type Salary = Double :| Interval[30000.0, 100000.0]
type Normalized = Float :| Interval[0.0f, 1.0f]

val low: Score = 0              // OK (inclusive)
val high: Score = 100           // OK (inclusive)
val mid: Score = 50             // OK
val under: Score = -1           // Compile-time error
val over: Score = 101           // Compile-time error
```

### Range[V1, V2]

Value must be between V1 and V2, **exclusive** on both ends.

```scala
type ExclusiveRange = Int :| Range[0, 10]
type NonZeroDouble = Double :| Range[-1.0, 1.0]

val mid: ExclusiveRange = 5     // OK
val low: ExclusiveRange = 0     // Compile-time error (exclusive)
val high: ExclusiveRange = 10   // Compile-time error (exclusive)
```

### Even / Odd

Built-in parity constraints on integral types.

```scala
type EvenInt = Int :| Even
type OddInt = Int :| Odd

val e: EvenInt = 4              // OK
val o: EvenInt = 3              // Compile-time error
```

### DivisibleBy[V]

Value must be divisible by V (custom — requires a type class instance).

```scala
final class DivisibleBy[V]
object NumericConstraints:
  given Constraint[Int, DivisibleBy[3]] with
    def message = "Number must be divisible by 3"
    def test(value: Int): Boolean = value % 3 == 0

type MultipleOfThree = Int :| DivisibleBy[3]
```

## String Constraints

All string constraints live in `io.github.iltotore.iron.constraint.string.*`.

### Contain[sub]

String must contain the literal substring `sub`.

```scala
type HasAt = String :| Contain["@"]
type HasEx = String :| Contain["!"]
type HasA = String :| Contain["a"]

val ok: HasAt = "user@host"     // OK
val fail: HasAt = "userhost"    // Compile-time error
```

### StartWith[sub]

String must start with the literal substring `sub`.

```scala
type HttpUrl = String :| StartWith["http://"]
type HttpsUrl = String :| StartWith["https://"]
type Prefix = String :| StartWith["prefix-"]
type PhonePrefix = String :| StartWith["+"]

val url: HttpUrl = "http://example.com"   // OK
val bad: HttpUrl = "ftp://example.com"    // Compile-time error
```

### EndWith[sub]

String must end with the literal substring `sub`.

```scala
type Tld = String :| EndWith[".com"]
type JsonExt = String :| EndWith[".json"]
type LogSuffix = String :| EndWith[" - finished"]

val site: Tld = "example.com"    // OK
val bad: Tld = "example.org"     // Compile-time error
```

### Length[V]

String must have exactly `V` characters.

```scala
type FourChars = String :| Length[4]
type TenChars = String :| Length[10]

val ok: FourChars = "abcd"       // OK
val bad: FourChars = "abc"       // Compile-time error
```

### Length[V1, V2]

String length must be between V1 and V2, inclusive.

```scala
type ShortName = String :| Length[2, 10]
type MediumDesc = String :| Length[50, 500]
type ValidPassword = String :| Length[8, 100]

val ok: ShortName = "alice"      // OK (5 chars, in range)
val short: ShortName = "a"       // Compile-time error (1 char)
val long: ShortName = "a" * 15   // Compile-time error (15 chars)
```

### Pattern[regex]

String must match the given regular expression.

```scala
type PostalCode = String :| Pattern["^[0-9]{5}$"]
type EmailPattern = String :| Pattern["^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"]
type PhoneNumber = String :| Pattern["^\\+?[0-9]{10,15}$"]

val zip: PostalCode = "12345"    // OK
val bad: PostalCode = "12A45"    // Compile-time error
```

### MinLength[V] / MaxLength[V]

Shorthand for minimum/maximum length constraints.

```scala
type MinThree = String :| MinLength[3]
type MaxHundred = String :| MaxLength[100]
```

### Trimmed

String must have no leading or trailing whitespace.

```scala
type CleanString = String :| Trimmed

val ok: CleanString = "hello"       // OK
val bad: CleanString = " hello "    // Compile-time error
```

### Letters

String must contain only letters.

```scala
type AlphaOnly = String :| Letters

val ok: AlphaOnly = "hello"     // OK
val bad: AlphaOnly = "hello123" // Compile-time error
```

### Digits

String must contain only digits.

```scala
type NumericOnly = String :| Digits

val ok: NumericOnly = "12345"     // OK
val bad: NumericOnly = "12a45"    // Compile-time error
```

### LettersOrDigits

String must contain only alphanumeric characters.

```scala
type Alphanumeric = String :| LettersOrDigits

val ok: Alphanumeric = "hello123"   // OK
val bad: Alphanumeric = "hello 123" // Compile-time error (space)
```

### Match[regex]

Alias/variant of Pattern for regex matching.

```scala
type Slug = String :| Match["^[a-z0-9-]+$"]
```

## Collection Constraints

All collection constraints live in `io.github.iltotore.iron.constraint.collection.*`.

### NonEmpty

Collection must contain at least one element.

```scala
type NonEmptyList = List[Int] :| NonEmpty
type NonEmptyVector = Vector[String] :| NonEmpty
type NonEmptySet = Set[Double] :| NonEmpty
type NonEmptySeq = Seq[Char] :| NonEmpty

val ok: NonEmptyList = List(1, 2, 3)   // OK
val bad: NonEmptyList = List()          // Compile-time error
```

### Size[V]

Collection must have exactly `V` elements.

```scala
type ExactlyFive = List[String] :| Size[5]
type SizeTen = Map[Int, String] :| Size[10]
type ThreeElements = Set[Int] :| Size[3]

val ok: ExactlyFive = List("a", "b", "c", "d", "e")  // OK
val bad: ExactlyFive = List("a", "b")                  // Compile-time error
```

### MinSize[V] / MaxSize[V]

Collection size must be at least / at most `V`.

```scala
type AtLeastThree = List[String] :| MinSize[3]
type AtMostHundred = List[Int] :| MaxSize[100]
```

### Unique

All elements in the collection must be unique.

```scala
type UniqueStrings = List[String] :| Unique
type UniqueInts = Vector[Int] :| Unique

val ok: UniqueStrings = List("a", "b", "c")    // OK
val bad: UniqueStrings = List("a", "a", "b")   // Compile-time error
```

### ForAll[C]

Every element in the collection must satisfy constraint `C`.

```scala
type AllPositive = List[Int] :| ForAll[Positive]
type AllNonEmpty = List[String] :| ForAll[NonEmpty]
```

### Contains[T]

Collection must contain an element of type `T`.

```scala
type HasInt = List[Double] :| Contains[Int]
type HasString = Vector[Any] :| Contains[String]
```

## Constraint Composition Operators

### Intersection (&) — AND logic

All constraints must be satisfied.

```scala
type ValidAge = Int :| (Greater[18] & Less[120])
type ValidPassword = String :| (Length[8, 100] & Contain["!"] & Contain["@"])
type PositiveEven = Int :| (Greater[0] & Even)
```

### Union (|) — OR logic

At least one constraint must be satisfied.

```scala
type NonZero = Double :| (Positive | Negative)
type EvenOrOdd = Int :| (Even | Odd)   // always true, demo only
```

### Implication (==>) — conditional

If the left constraint holds, the right must also hold.

```scala
type AdultAge = Int :| (Greater[18] ==> Less[120])
```

## Import Patterns

```scala
// All core constraints
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.github.iltotore.iron.constraint.collection.*

// Numeric only
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.numeric.*

// String only
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.string.*

// Collection only
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.collection.*
```

## Error Message Format

Compile-time errors show the value and constraint message:

```
-- Constraint Error --------------------------------------------------------
Could not satisfy a constraint for type scala.Int.

Value: -5
Message: Should be greater than 0
----------------------------------------------------------------------------
```

Runtime errors via `refineEither` return `Left("Should be greater than 0")`.
