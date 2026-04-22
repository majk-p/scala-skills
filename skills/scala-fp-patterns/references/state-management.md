# State Management Reference

Complete reference for functional state management patterns in Scala.

## Decision Guide: Ref vs StateT vs AtomicCell vs MTL Stateful

| Approach | Concurrency | Purity | Testability | Use When |
|----------|-------------|--------|-------------|----------|
| `Ref` | Yes | Effectful | Medium | Shared state across fibers: counters, caches, registries |
| `StateT` | No | Pure | High | Pure state transitions, no IO during update |
| `AtomicCell` | Yes | Effectful | Medium | Atomic compare-and-swap, consistent read-modify-write |
| MTL `Stateful` | Varies | Polymorphic | High | Effect-polymorphic state access |

```scala
import cats.effect.{IO, Ref}
import cats.data.StateT
import cats.effect.std.AtomicCell
import cats.mtl.Stateful

// Ref: concurrent shared counter
def counterProgram: IO[Int] = for {
  ref <- Ref.of[IO, Int](0)
  _ <- List.fill(100)(ref.update(_ + 1)).parSequence; result <- ref.get
} yield result

// StateT: pure state machine (no IO during state change)
type Pure[A] = StateT[Either[String, *], Map[String, Int], A]
def increment(key: String): Pure[Unit] = StateT.modify(_.updatedWith(key)(_.map(_ + 1).orElse(Some(1))))

// AtomicCell: atomic compare-and-swap
class AccountBalance(cell: AtomicCell[IO, Int]) {
  def withdraw(amt: Int): IO[Either[String, Int]] = cell.modify { b =>
    if (b >= amt) (b - amt, Right(b - amt)) else (b, Left("Insufficient funds"))
  }
}

// MTL Stateful: effect-polymorphic
def incrementCounter[F[_]](implicit S: Stateful[F, Int]): F[Int] =
  S.get.flatMap(c => S.set(c + 1).as(c + 1))
```

## StateT Deep Dive

```scala
import cats.data.StateT
import cats.effect.IO

case class AppStateData(
  userBalance: Map[String, Int] = Map.empty,
  transactionCount: Int = 0,
  metadata: Map[String, String] = Map.empty
)
type AppState[A] = StateT[IO, AppStateData, A]

// Primitives
val getState: AppState[AppStateData] = StateT.get
def modifyState(f: AppStateData => AppStateData): AppState[Unit] = StateT.modify(f)
def inspectState[A](f: AppStateData => A): AppState[A] = StateT.inspect(f)

// Compose stateful operations
def transfer(from: String, to: String, amount: Int): AppState[Unit] = for {
  state <- StateT.get[IO, AppStateData]
  fromBal = state.userBalance.getOrElse(from, 0)
  _ <- if (fromBal < amount)
    StateT.liftF[IO, AppStateData, Unit](IO.raiseError(new Exception("Insufficient funds")))
  else StateT.pure[IO, AppStateData, Unit](())
  _ <- StateT.modify[IO, AppStateData] { s =>
    s.copy(userBalance = s.userBalance + (from -> (fromBal - amount)),
           transactionCount = s.transactionCount + 1)
  }
  _ <- StateT.modify[IO, AppStateData] { s =>
    s.copy(userBalance = s.userBalance + (to -> (s.userBalance.getOrElse(to, 0) + amount)))
  }
} yield ()

// Lift effects into StateT
def logState[F[_]: Sync]: StateT[F, AppStateData, Unit] =
  StateT.liftF(Sync[F].delay(println("State accessed")))
```

## MTL Transformers

```scala
import cats.mtl.{Stateful, Local}
import cats.effect.Concurrent

// Stateful — effect-polymorphic state access
def updateBalance[F[_]](userId: String, amount: Int)(
  implicit S: Stateful[F, Map[String, Int]]
): F[Unit] = for {
  current <- S.get
  _ <- S.set(current + (userId -> (current.getOrElse(userId, 0) + amount)))
} yield ()

// Local — scoped state
def withLocalState[F[_]: Concurrent: Local[*[_], Int], A](value: Int)(f: F[A]): F[A] =
  Local[F, Int].scope(value)(f)
```

## AtomicCell for Concurrent State

```scala
import cats.effect.std.AtomicCell
import cats.effect.Sync

class ConcurrentCounter[F[_]: Sync](cell: AtomicCell[F, Int]) {
  def increment: F[Int] = cell.modify(_ + 1)
  def decrement: F[Int] = cell.modify(_ - 1)
  def get: F[Int]       = cell.get
}
```

## Practical Example: Shopping Cart

### StateT Version — Pure and Fully Testable

```scala
import cats.data.StateT
import cats.syntax.all._

case class Item(id: String, name: String, price: BigDecimal)
case class CartItem(item: Item, quantity: Int) {
  def subtotal: BigDecimal = item.price * quantity
}
case class CartState(items: Map[String, CartItem] = Map.empty, discount: BigDecimal = 0) {
  def subtotal: BigDecimal = items.values.map(_.subtotal).sum
  def total: BigDecimal    = (subtotal - discount).max(0)
}

type Cart[A] = StateT[Either[String, *], CartState, A]

def addItem(item: Item, qty: Int): Cart[Unit] = StateT.modify { s =>
  val ci = s.items.get(item.id).fold(CartItem(item, qty))(c => c.copy(quantity = c.quantity + qty))
  s.copy(items = s.items.updated(item.id, ci))
}

def removeItem(itemId: String): Cart[Unit] = StateT.modifyF { s =>
  Either.cond(s.items.contains(itemId), s.copy(items = s.items - itemId), s"Item $itemId not in cart")
}

def updateQuantity(itemId: String, qty: Int): Cart[Unit] = StateT.modifyF { s =>
  for {
    ci <- s.items.get(itemId).toRight(s"Item $itemId not in cart")
    _  <- Either.cond(qty > 0, (), "Quantity must be positive")
  } yield s.copy(items = s.items.updated(itemId, ci.copy(quantity = qty)))
}

def applyDiscount(amount: BigDecimal): Cart[Unit] = StateT.modifyF { s =>
  Either.cond(amount >= 0 && amount <= s.subtotal, s.copy(discount = amount), "Invalid discount")
}

// Compose operations
val checkout: Cart[BigDecimal] = for {
  _ <- addItem(Item("p1", "Scala Book", BigDecimal("49.99")), 2)
  _ <- addItem(Item("p2", "FP Sticker", BigDecimal("3.50")), 5)
  _ <- updateQuantity("p2", 3)
  _ <- applyDiscount(BigDecimal("10.00"))
  total <- StateT.inspect[Either[String, *], CartState, BigDecimal](_.total)
} yield total
```

### Ref Version — Concurrent Cart

```scala
import cats.effect.{IO, Ref}

class ConcurrentCart(ref: Ref[IO, CartState]) {
  def addItem(item: Item, qty: Int): IO[Unit] = ref.update { s =>
    val ci = s.items.get(item.id).fold(CartItem(item, qty))(c => c.copy(quantity = c.quantity + qty))
    s.copy(items = s.items.updated(item.id, ci))
  }

  def removeItem(itemId: String): IO[Either[String, Unit]] = ref.modify { s =>
    if (s.items.contains(itemId)) (s.copy(items = s.items - itemId), Right(()))
    else (s, Left(s"Item $itemId not in cart"))
  }

  def updateQuantity(itemId: String, qty: Int): IO[Either[String, Unit]] = ref.modify { s =>
    s.items.get(itemId) match {
      case Some(ci) if qty > 0 => (s.copy(items = s.items.updated(itemId, ci.copy(quantity = qty))), Right(()))
      case Some(_) => (s, Left("Quantity must be positive"))
      case None    => (s, Left(s"Item $itemId not in cart"))
    }
  }

  def total: IO[BigDecimal] = ref.get.map(_.total)
}

object ConcurrentCart {
  def create: IO[ConcurrentCart] = Ref.of[IO, CartState](CartState()).map(new ConcurrentCart(_))
}
```

## Concurrent State Patterns

### Deferred for One-Time Initialization

```scala
import cats.effect.{Deferred, IO, Ref}
import cats.syntax.all._

case class Config(dbUrl: String, poolSize: Int)

class OnceInitializedConfig(ref: Ref[IO, Option[Config]], deferred: Deferred[IO, Config]) {
  def initialize(cfg: Config): IO[Unit] = for {
    wasFirst <- ref.modify { case None => (Some(cfg), true); case s => (s, false) }
    _ <- IO.whenA(wasFirst)(deferred.complete(cfg))
  } yield ()
  def config: IO[Config] = deferred.get // blocks until initialized
}
```

### Semaphore for Rate-Limited Access

```scala
import cats.effect.std.Semaphore
import cats.effect.{IO, Ref}

class RateLimitedCache[K, V](cache: Ref[IO, Map[K, V]], sem: Semaphore[IO]) {
  def get(key: K): IO[Option[V]]      = sem.permit.use(_ => cache.get.map(_.get(key)))
  def put(key: K, value: V): IO[Unit] = sem.permit.use(_ => cache.update(_ + (key -> value)))
}
```

### Atomic Updates with Ref.modify

```scala
import cats.effect.{IO, Ref}

def transferAmount(from: String, to: String, amount: Int)(
  ref: Ref[IO, Map[String, Int]]
): IO[Either[String, Unit]] = ref.modify { balances =>
  val fromBal = balances.getOrElse(from, 0)
  if (fromBal >= amount)
    (balances.updated(from, fromBal - amount).updated(to, balances.getOrElse(to, 0) + amount), Right(()))
  else (balances, Left(s"Insufficient funds: $from has $fromBal, needs $amount"))
}
```

### Stateful Stream Processing with Ref + fs2

```scala
import cats.effect.{IO, Ref}
import fs2.Stream

// Sliding window sum
def slidingSum(windowSize: Int)(stream: Stream[IO, Int]): Stream[IO, Int] =
  Stream.eval(Ref.of[IO, List[Int]](Nil)).flatMap { buffer =>
    stream.evalMap { v =>
      buffer.modify { h => val u = (v :: h).take(windowSize); (u, u.sum) }
    }
  }
```

## Resource-Safe State Initialization

### Database Connection Pool

```scala
import cats.effect.{IO, Ref, Resource}
import cats.syntax.all._

case class DbConnection(id: Int)

class ConnectionPool(available: Ref[IO, List[DbConnection]], inUse: Ref[IO, Set[DbConnection]]) {
  def acquire: Resource[IO, DbConnection] = Resource.make {
    available.modify {
      case conn :: rest => (rest, IO.pure(conn))
      case Nil          => (Nil, IO.raiseError(new Exception("Pool exhausted")))
    }.flatten
  }(conn => inUse.update(_ - conn) >> available.update(conn :: _))
}

object ConnectionPool {
  def create(maxSize: Int): Resource[IO, ConnectionPool] = for {
    conns <- Resource.eval((1 to maxSize).toList.traverse(i => IO(DbConnection(i))))
    avail <- Resource.eval(Ref.of[IO, List[DbConnection]](conns))
    used  <- Resource.eval(Ref.of[IO, Set[DbConnection]](Set.empty))
    _     <- Resource.onFinalize(IO.println("Pool shut down"))
  } yield new ConnectionPool(avail, used)
}
```

### Cache with TTL and Background Eviction

```scala
import cats.effect.{IO, Ref, Resource}
import scala.concurrent.duration._

case class CacheEntry[A](value: A, expiresAt: FiniteDuration)

class TtlCache[K, V](ref: Ref[IO, Map[K, CacheEntry[V]]], ttl: FiniteDuration) {
  def get(key: K): IO[Option[V]] = for {
    now <- IO.monotonic; entries <- ref.get
  } yield entries.get(key).filter(_.expiresAt > now).map(_.value)

  def put(key: K, value: V): IO[Unit] = for {
    now <- IO.monotonic; _ <- ref.update(_ + (key -> CacheEntry(value, now + ttl)))
  } yield ()

  def evictExpired: IO[Int] = for {
    now <- IO.monotonic
    n <- ref.modify { m => val (expired, valid) = m.partition(_._2.expiresAt <= now); (valid, expired.size) }
  } yield n
}

object TtlCache {
  def resource[K, V](ttl: FiniteDuration, evictInterval: FiniteDuration): Resource[IO, TtlCache[K, V]] = for {
    ref   <- Resource.eval(Ref.of[IO, Map[K, CacheEntry[V]]](Map.empty))
    cache  = new TtlCache[K, V](ref, ttl)
    _     <- fs2.Stream.awakeEvery[IO](evictInterval).evalMap(_ => cache.evictExpired).compile.drain.background
  } yield cache
}
```

## State Recovery and Persistence

### Snapshotting State

```scala
import cats.effect.{IO, Ref}
import cats.syntax.all._

case class AppState(users: Map[String, User], version: Long)
case class User(name: String, email: String)

class SnapshottableState(ref: Ref[IO, AppState], history: Ref[IO, List[AppState]]) {
  def snapshot: IO[Unit] = ref.get.flatMap(s => history.update(s :: _))
  def restore: IO[Unit] = history.get.flatMap(_.headOption.liftTo(IO(new Exception("No snapshots"))).flatMap(s =>
    ref.set(s) >> history.update(_.tail)))
  def update(f: AppState => AppState): IO[Unit] = ref.update(f)
  def get: IO[AppState] = ref.get
}
```

### Event Sourcing Basics

```scala
import cats.effect.{IO, Ref}
import cats.syntax.all._

sealed trait CartEvent
case class ItemAdded(itemId: String, name: String, price: BigDecimal, qty: Int) extends CartEvent
case class ItemRemoved(itemId: String) extends CartEvent
case class DiscountApplied(amount: BigDecimal) extends CartEvent

case class ReadCart(items: Map[String, (String, BigDecimal, Int)] = Map.empty, discount: BigDecimal = 0) {
  def total: BigDecimal = (items.values.map { case (_, p, q) => p * q }.sum - discount).max(0)
}

class EventSourcedCart(events: Ref[IO, Vector[CartEvent]], snapshot: Ref[IO, ReadCart]) {
  private def applyEvent(cart: ReadCart, e: CartEvent): ReadCart = e match {
    case ItemAdded(id, name, price, qty) => cart.copy(items = cart.items.updated(id, (name, price, qty)))
    case ItemRemoved(id)                 => cart.copy(items = cart.items - id)
    case DiscountApplied(amt)            => cart.copy(discount = amt)
  }

  def publish(event: CartEvent): IO[Unit] =
    events.update(_ :+ event) >> snapshot.modify(c => (applyEvent(c, event), ()))

  def currentCart: IO[ReadCart]       = snapshot.get
  def eventLog: IO[Vector[CartEvent]] = events.get
  def rebuildFromEvents: IO[Unit]     = events.get.flatMap(ev => snapshot.set(ev.foldLeft(ReadCart())(applyEvent)))
}

object EventSourcedCart {
  def create: IO[EventSourcedCart] = for {
    events <- Ref.of[IO, Vector[CartEvent]](Vector.empty)
    snap   <- Ref.of[IO, ReadCart](ReadCart())
  } yield new EventSourcedCart(events, snap)
}
```

## Resource-Safe State Management

```scala
import cats.effect.{Resource, Ref, Sync}

def createStatefulResource[F[_]: Sync]: Resource[F, Ref[F, Map[String, Int]]] =
  Resource.make(Ref.of[F, Map[String, Int]](Map.empty)) { ref =>
    Sync[F].delay(println("Cleaning up state"))
  }
```
