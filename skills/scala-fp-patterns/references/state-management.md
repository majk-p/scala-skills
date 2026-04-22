# State Management Reference

Complete reference for functional state management patterns in Scala.

## StateT Deep Dive

### Creating StateT Values

```scala
import cats.data.StateT
import cats.effect.IO

type AppState[A] = StateT[IO, AppStateData, A]

case class AppStateData(
  userBalance: Map[String, Int] = Map.empty,
  transactionCount: Int = 0,
  metadata: Map[String, String] = Map.empty
)

// Get current state
val getState: AppState[AppStateData] = StateT.get

// Modify state
def modifyState(f: AppStateData => AppStateData): AppState[Unit] =
  StateT.modify(f)

// Inspect without modifying
def inspectState[A](f: AppStateData => A): AppState[A] =
  StateT.inspect(f)

// Pure value without state change
def pureState[A](a: A): AppState[A] = StateT.pure(a)
```

### Composing State Transformations

```scala
def transfer(from: String, to: String, amount: Int): AppState[Unit] = for {
  state <- StateT.get[IO, AppStateData]
  fromBalance = state.userBalance.getOrElse(from, 0)
  _ <- if (fromBalance < amount)
    StateT.liftF[IO, AppStateData, Unit](IO.raiseError(new Exception("Insufficient funds")))
  else StateT.pure[IO, AppStateData, Unit](())
  _ <- StateT.modify[IO, AppStateData] { s =>
    s.copy(
      userBalance = s.userBalance + (from -> (fromBalance - amount)),
      transactionCount = s.transactionCount + 1
    )
  }
  _ <- StateT.modify[IO, AppStateData] { s =>
    val toBalance = s.userBalance.getOrElse(to, 0)
    s.copy(userBalance = s.userBalance + (to -> (toBalance + amount)))
  }
} yield ()
```

### Lifting Effects into StateT

```scala
// Lift an IO effect into StateT
def logState[F[_]: Sync]: StateT[F, AppStateData, Unit] =
  StateT.liftF[F, AppStateData, Unit](Sync[F].delay(println("State accessed")))
```

## MTL Transformers

### Stateful

```scala
import cats.mtl.Stateful

// Effect-polymorphic state access
def updateBalance[F[_]](userId: String, amount: Int)(implicit S: Stateful[F, Map[String, Int]]): F[Unit] =
  for {
    current <- S.get
    _ <- S.set(current + (userId -> (current.getOrElse(userId, 0) + amount)))
  } yield ()
```

### Local

```scala
import cats.mtl.Local
import cats.effect.Concurrent

def withLocalState[F[_]: Concurrent: Local[*[_], Int], A](
  localState: Int
)(f: F[A]): F[A] = Local[F, Int].scope(localState)(f)

def processWithContext[F[_]: Concurrent: Local[*[_], Int]]: F[Unit] = for {
  initial <- Local[F, Int].ask
  _ <- withLocalState(10) {
    Local[F, Int].ask.flatMap(v => Concurrent[F].delay(println(s"Inside: $v")))
  }
} yield ()
```

## AtomicCell for Concurrent State

```scala
import cats.effect.std.AtomicCell
import cats.effect.{Concurrent, Sync}
import cats.implicits._

class ConcurrentCounter[F[_]: Sync] {
  private val cell = AtomicCell.of[F, Int](0)

  def increment: F[Int] = cell.flatMap(_.modify(_ + 1))
  def decrement: F[Int] = cell.flatMap(_.modify(_ - 1))
  def get: F[Int] = cell.flatMap(_.get)
}
```

## Resource-Safe State Management

```scala
import cats.effect.Resource

def createStatefulResource[F[_]: Sync]: Resource[F, Ref[F, Map[String, Int]]] =
  Resource.make(Ref.of[F, Map[String, Int]](Map.empty)) { ref =>
    Sync[F].delay(println("Cleaning up state"))
  }
```
