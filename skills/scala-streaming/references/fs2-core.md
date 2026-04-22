# fs2 Core Reference

Complete reference for fs2 Stream API, transformations, pipes, Chunk operations, compilation, resource safety, error handling, and testing.

## Core Types

### Stream[F, O]

```scala
// Type signature
final class Stream[+F[_], +O] private[fs2](private[fs2] val underlying: Pull[F, O, Unit])

// Key properties:
// - F[_]: Effect type (IO, ZIO, etc.) — polymorphic
// - O: Output type
// - Lazy: values computed only when consumed
// - Pull-based: consumer controls evaluation
```

### Special Stream Types

```scala
val pure: Stream[Pure, Int]    = Stream(1, 2, 3)    // no effects
val effect: Stream[IO, Int]    = Stream.eval(IO(42)) // effectful
val infinite: Stream[IO, Int]  = Stream.constant(42) // never-ending
val never: Stream[IO, Nothing] = Stream.never        // produces nothing, never ends
val empty: Stream[IO, Int]     = Stream.empty
```

### Chunk Type

```scala
sealed trait Chunk[+O] {
  def size: Int
  def isEmpty: Boolean
  def nonEmpty: Boolean
  def apply(i: Int): O
  def map[O2](f: O => O2): Chunk[O2]
}

Chunk.empty[Int]
Chunk.singleton(42)
Chunk.seq(List(1, 2, 3))
Chunk.array(Array(1, 2, 3))
Chunk.vector(Vector(1, 2, 3))
```

### Pipe and Sink Types

```scala
type Pipe[F[_], -I, +O] = Stream[F, I] => Stream[F, O]
type Sink[F[_], -I]     = Pipe[F, I, INothing]

val filterPipe: Pipe[IO, Int, Int]     = _.filter(_ > 0)
val mapPipe: Pipe[IO, Int, String]     = _.map(_.toString)
val transformPipe: Pipe[IO, Int, Int]  = _.flatMap(i => Stream(i, i * 2))

// Combining pipes
val pipeline: Pipe[IO, Int, String] =
  filterPipe.andThen(_.map(_.toString))
```

## Creating Streams

### Single Values and Sequences

```scala
Stream.emit(42)              // single value
Stream.emit(1, 2, 3)         // multiple values
Stream.emits(Seq(1, 2, 3))   // from sequence
Stream.empty[Int]            // empty
Stream.constant(42).take(3)  // infinite, take N
```

### Range Streams

```scala
Stream.range(0, 10)              // 0..9
Stream.range(0, 10, 2)          // 0, 2, 4, 6, 8
Stream.range(10, 0, -1)         // 10, 9, ..., 1
```

### From Iterators and Effects

```scala
Stream.fromIterator(iterator)           // non-blocking
Stream.fromIteratorBlocking(iterator)   // blocking context

Stream.eval(IO(42))                              // single effect
Stream.emits(List(IO(1), IO(2))).evalMap(identity) // multiple effects
Stream.evalTraverse(List(1, 2, 3))(i => IO(i * 2)) // traverse
Stream.repeatEval(IO(42)).take(3)                 // repeat effect
```

### Unfold

```scala
// Generate from seed
Stream.unfold(0)(n => if (n >= 10) None else Some((n, n + 1)))
// 0, 1, 2, ..., 9

// With effects
Stream.unfoldEval(0)(n => IO(if (n >= 10) None else Some((n, n + 1))))
```

## Transformations

### Pure Operations

```scala
.map(_ * 2)                          // transform each element
.flatMap(i => Stream(i, i * 2))      // monadic bind
.filter(_ % 2 == 0)                  // filter
.collect { case i: Int => i }        // partial function collect
.collectFirst { case Some(i) => i }  // first match
.collectWhile { case Some(i) => i }  // until no match

.take(5)           // first N
.drop(3)           // skip first N
.takeWhile(_ < 5)  // take until condition fails
.dropWhile(_ < 5)  // drop until condition fails
.takeRight(3)      // last N
.dropRight(3)      // all but last N
```

### Scanning and Folding

```scala
.scan(0)(_ + _)   // running fold: 0, 1, 3, 6, 10
.scan1(_ + _)      // running fold without initial: 1, 3, 6, 10

// Terminal (require compile)
.compile.fold(0)(_ + _)     // IO[Int]
.compile.foldMonoid          // IO[A] (uses Monoid)
.compile.toList              // IO[List[O]]
.compile.toVector            // IO[Vector[O]]
.compile.last                // IO[Option[O]]
.compile.head                // IO[O] (throws if empty)
.compile.drain               // IO[Unit]
```

### Boolean Operations

```scala
.exists(_ == 5)    // Stream[F, Boolean]
.forall(_ < 10)    // Stream[F, Boolean]
```

## Pipes

### Common Built-in Pipes

```scala
import fs2.text

val encode: Pipe[IO, String, Byte]  = text.utf8Encode
val decode: Pipe[IO, Byte, String]  = text.utf8Decode
val lines: Pipe[IO, String, String] = text.lines

import fs2.compression
val compress: Pipe[IO, Byte, Byte]   = Compression[IO].gzip()
val decompress: Pipe[IO, Byte, Byte] = Compression[IO].gunzip()
```

### Through and Pipe Composition

```scala
// Apply pipe
Stream(1, 2, 3).through(filterPositive).through(_.map(_.toString))

// Chain pipes
filterPositive.andThen(_.map(_.toString))
```

### Pipe2 (Two-Input Pipes)

```scala
type Pipe2[F[_], -I, -I2, +O] = (Stream[F, I], Stream[F, I2]) => Stream[F, O]

// Zip
val zipped: Stream[IO, (Int, String)] = s1.zip(s2)
val summed = s1.zipWith(s2)(_ + _.length)
val interleaved = s1.interleave(s2)
```

## Resource Safety

### Bracket

```scala
Stream.bracket(IO(openResource()))(
  use = r => Stream.eval(useResource(r))
)(release = r => IO(closeResource(r)))
```

### Bracket Case (exit-case-aware cleanup)

```scala
Stream.bracketCase(IO.open())(
  use = conn => Stream.eval(conn.query("SELECT *"))
)(release = (conn, exitCase) => exitCase match {
  case ExitCase.Succeeded  => IO(conn.close())
  case ExitCase.Errored(e) => IO(conn.close()) >> IO(e.printStackTrace())
  case ExitCase.Canceled   => IO(conn.close())
})
```

### Resource Integration

```scala
def dbConn: Resource[IO, Connection] =
  Resource.make(IO.openConnection())(c => IO(c.close()))

// Single resource
Stream.resource(dbConn).flatMap(conn => Stream.eval(conn.query("SELECT 1")))

// Multiple resources
for {
  db    <- Stream.resource(dbConn)
  cache <- Stream.resource(redisConn)
} yield queryWithCache(db, cache)
```

## Error Handling

```scala
// attempt: wrap elements/errors in Either
stream.attempt         // Stream[F, Either[Throwable, O]]
stream.attempt.rethrow // back to throwing

// handleErrorWith: recover with fallback stream
stream.handleErrorWith(e => Stream.emit(-1))

// Error-specific handling
stream.handleErrorWith {
  case _: ArithmeticException => Stream.emit(0)
  case e => Stream.raiseError[IO](e)
}

// ensure: validate elements
stream.ensure(new Exception("too big"))(_ < 100)

// retry with delay
stream.attempt.retry(Stream.fixedDelay[IO](1.second).take(3))
```

## Testing Streams

```scala
// Test pure stream output
assert(Stream(1, 2, 3).toList == List(1, 2, 3))

// Test effectful stream
val result = Stream(1, 2, 3).compile.toList.unsafeRunSync()
assert(result == List(1, 2, 3))

// Test error handling
val errorStream = Stream(1, 2, 3) ++ Stream.raiseError[IO](new Exception("boom"))
val attempted = errorStream.attempt.compile.toList.unsafeRunSync()
assert(attempted.size == 4)

// Test concurrency
val ref = Ref.of[IO, Int](0).unsafeRunSync()
Stream.range(0, 10).parEvalMap(5)(i => ref.update(_ + 1).as(i)).compile.drain.unsafeRunSync()
assert(ref.get.unsafeRunSync() == 10)
```

## Operator Summary

| Operator | Purpose | Returns |
|----------|---------|---------|
| `emit` | Single-element stream | `Stream[F, O]` |
| `emits` | From sequence | `Stream[F, O]` |
| `empty` | Empty stream | `Stream[F, O]` |
| `constant` | Repeat value infinitely | `Stream[F, O]` |
| `range` | Integer range | `Stream[F, Int]` |
| `eval` | From effect | `Stream[F, O]` |
| `unfold` | Generate from seed | `Stream[F, O]` |
| `map` | Transform each element | `Stream[F, O2]` |
| `flatMap` | Monadic bind | `Stream[F, O2]` |
| `filter` | Filter elements | `Stream[F, O]` |
| `evalMap` | Effectful map | `Stream[F, O2]` |
| `evalTap` | Side effect, preserve value | `Stream[F, O]` |
| `take` / `drop` | Take/drop first N | `Stream[F, O]` |
| `takeWhile` / `dropWhile` | Conditional take/drop | `Stream[F, O]` |
| `scan` | Running fold | `Stream[F, O2]` |
| `through` | Apply pipe | `Stream[F, O2]` |
| `compile` | Run stream | `F[G[O]]` |
| `attempt` | Wrap in Either | `Stream[F, Either]` |
| `handleErrorWith` | Error recovery | `Stream[F, O]` |
