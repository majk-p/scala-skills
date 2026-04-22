---
name: scala-akka
description: Use this skill when building concurrent, distributed, or resilient applications in Scala using the Akka actor model framework. Covers actor creation, message passing, supervision strategies, Akka Typed, Akka Streams basics, persistence, and clustering. Trigger when the user mentions Akka, actors, actor model, message-driven architecture, supervision, clustering, Akka Streams, Akka Persistence, or needs to build reactive, fault-tolerant systems.
---

# Akka Actor Model in Scala

Akka provides a platform for building concurrent, distributed, and fault-tolerant systems using the actor model. Actors are lightweight concurrent objects that communicate via asynchronous message passing, isolated from each other and supervised by parent actors.

## Quick Start

```scala
import akka.actor.typed.{ActorRef, ActorSystem, Behavior}
import akka.actor.typed.scaladsl.Behaviors

object Greeter {
  sealed trait Command
  case class Greet(name: String, replyTo: ActorRef[String]) extends Command

  def apply(): Behavior[Command] = Behaviors.setup { context =>
    Behaviors.receiveMessage {
      case Greet(name, replyTo) =>
        context.log.info(s"Hello, $name")
        replyTo ! s"Greeted $name"
        Behaviors.same
    }
  }
}

// Create actor system
implicit val system: ActorSystem[Greeter.Command] = ActorSystem(Greeter(), "my-system")
```

## Core Concepts

- **Actors**: Lightweight, concurrent objects that communicate via messages
- **Message Passing**: Asynchronous, non-blocking communication
- **Immutable Messages**: Messages should be immutable and typed
- **Supervision**: Parent actors supervise children with fault isolation strategies
- **Let it Crash**: Fail-fast philosophy — let supervisors handle recovery
- **Actor Ref**: Reference to an actor for sending messages (never share `this`)
- **Mailboxes**: Message queues for each actor
- **Dispatchers**: Thread pools that execute actor messages

## Creating Actors (Akka Typed)

### Counter Actor

```scala
object Counter {
  sealed trait Command
  case class Increment(amount: Int) extends Command
  case class Decrement(amount: Int) extends Command
  case class GetValue(replyTo: ActorRef[Int]) extends Command

  def apply(): Behavior[Command] = Behaviors.setup { context =>
    var count = 0

    Behaviors.receiveMessage {
      case Increment(amount) =>
        count += amount
        Behaviors.same
      case Decrement(amount) =>
        count -= amount
        Behaviors.same
      case GetValue(replyTo) =>
        replyTo ! count
        Behaviors.same
    }
  }
}
```

### Sending Messages

```scala
// Tell pattern (fire-and-forget)
counter ! Counter.Increment(5)
counter ! Counter.Decrement(2)

// Ask pattern (request-response with timeout)
import akka.actor.typed.scaladsl.AskPattern._
import scala.concurrent.duration._
implicit val timeout: akka.util.Timeout = 3.seconds

val result: Future[Int] = counter.ask(Counter.GetValue(_))
```

## Supervision Strategies

```scala
import akka.actor.typed.SupervisorStrategy

// Restart on failure
def supervisedActor: Behavior[Command] =
  Behaviors.supervise(MyActor())
    .onFailure[Exception](SupervisorStrategy.restart)

// Restart with backoff
def backoffSupervised: Behavior[Command] =
  Behaviors.supervise(MyActor())
    .onFailure[Exception](
      SupervisorStrategy.restart
        .withLimit(maxNrOfRetries = 3, withinTimeRange = 1.minute)
    )

// Manual error handling inside actor
def resilientActor: Behavior[Command] = Behaviors.setup { context =>
  Behaviors.receiveMessage {
    case cmd =>
      try {
        // Process command
        Behaviors.same
      } catch {
        case _: ArithmeticException =>
          context.log.warning("Arithmetic error, restarting")
          Behaviors.restart
        case _: IllegalArgumentException =>
          context.log.warning("Illegal argument, resuming")
          Behaviors.same
        case _: Exception =>
          context.log.error("Unexpected error, stopping")
          Behaviors.stopped
      }
  }
}
```

## Akka Streams Basics

```scala
import akka.stream.scaladsl._
import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors

implicit val system: ActorSystem[Nothing] = ActorSystem(Behaviors.empty, "streams")

val source = Source(1 to 10)
val sink = Sink.foreach[Int](println)

// Compose stream
source
  .map(_ * 2)
  .filter(_ % 3 == 0)
  .runWith(sink)

// Flow transformation
val flow: Flow[Int, String, _] = Flow[Int].map(i => s"Item: $i")
source.via(flow).runWith(Sink.foreach(println))
```

## Akka Persistence

```scala
import akka.persistence.typed.scaladsl.{EventSourcedBehavior, Effect}
import akka.persistence.typed.PersistenceId

object TodoItem {
  // Command protocol
  sealed trait Command
  case class Create(text: String, replyTo: ActorRef[Created]) extends Command
  case class Get(replyTo: ActorRef[State]) extends Command

  // Events
  sealed trait Event
  case class Created(text: String) extends Event

  // State
  case class State(text: Option[String] = None)

  def apply(id: String): Behavior[Command] =
    EventSourcedBehavior[Command, Event, State](
      persistenceId = PersistenceId.ofUniqueId(id),
      emptyState = State(),
      commandHandler = (state, command) => command match {
        case Create(text, replyTo) =>
          Effect.persist(Created(text)).thenRun { _ =>
            replyTo ! Created(text)
          }
        case Get(replyTo) =>
          replyTo ! state
          Effect.none
      },
      eventHandler = (state, event) => event match {
        case Created(text) => State(Some(text))
      }
    )
}
```

## Cluster Basics

```scala
import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors
import akka.cluster.typed.Cluster
import akka.cluster.typed.Join

// Minimum cluster configuration (application.conf):
// akka.actor.provider = "cluster"
// akka.remote.artery.canonical.hostname = "127.0.0.1"
// akka.remote.artery.canonical.port = 2551
// akka.cluster.seed-nodes = ["akka://my-system@127.0.0.1:2551"]

val system = ActorSystem(Behaviors.empty[Nothing], "my-system")
val cluster = Cluster(system)

// Join cluster
cluster.manager ! Join(cluster.selfMember.address)
```

## Testing Actors

```scala
import akka.actor.testkit.typed.scaladsl.{ActorTestKit, TestProbe}
import org.scalatest.wordspec.AnyWordSpecLike
import org.scalatest.matchers.should.Matchers

class CounterSpec extends AnyWordSpecLike with Matchers {
  val testKit = ActorTestKit()

  "Counter" should {
    "increment and get value" in {
      val probe = testKit.createTestProbe[Int]()
      val actor = testKit.spawn(Counter())

      actor ! Counter.Increment(5)
      actor ! Counter.GetValue(probe.ref)
      probe.expectMessage(5)
    }
  }
}
```

## Integration with Cats Effect

```scala
import akka.actor.typed.scaladsl.Behaviors
import cats.effect.{Async, Resource}
import akka.actor.typed.{ActorSystem, Behavior}

object AkkaCatsIntegration {
  def mkSystem[F[_]: Async]: Resource[F, ActorSystem[Nothing]] =
    Resource.make(
      Async[F].delay(ActorSystem(Behaviors.empty[Nothing], "cats-akka"))
    )(system => Async[F].delay(system.terminate()))
}
```

## Common Pitfalls

1. **Never block in actors** — consumes dispatcher threads. Use `ask` with timeout or pipe futures
2. **Always handle `Terminated` messages** in supervisor hierarchies
3. **Use Akka Typed** for new code — more type-safe than classic actors
4. **Always provide timeout for `ask`** to prevent deadlocks
5. **Clean up resources** with `Behaviors.stopped` or `PostStop` signal handling
6. **ActorSystem provides Materializer** — no need to create `ActorMaterializer` manually for streams

## Dependencies

```scala
// check for latest version
libraryDependencies += "com.typesafe.akka" %% "akka-actor-typed" % "2.10.+"
libraryDependencies += "com.typesafe.akka" %% "akka-stream" % "2.10.+"
libraryDependencies += "com.typesafe.akka" %% "akka-persistence-typed" % "2.10.+"
libraryDependencies += "com.typesafe.akka" %% "akka-cluster-typed" % "2.10.+"
libraryDependencies += "com.typesafe.akka" %% "akka-actor-testkit-typed" % "2.10.+" % Test
```

## Related Skills

- **scala-async-effects** — for integrating Akka with ZIO or cats-effect
- **scala-streaming** — for fs2 stream processing as an alternative to Akka Streams
- **scala-messaging** — for message queue integration with Akka actors

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/actor-reference.md** — Cluster sharding, custom mailboxes, dispatcher configuration, persistence snapshotting, MongoDB integration, Akka HTTP integration, advanced supervision patterns

## Scripts

- **scripts/new-akka-project.sh** — Scaffold a new Akka project with sbt
