# Akka Actor Reference

Complete reference for advanced Akka patterns, configuration, and integration.

## Cluster Sharding

Distribute actors across cluster nodes for horizontal scaling.

```scala
import akka.cluster.sharding.typed.scaladsl.{ClusterSharding, Entity}
import akka.cluster.sharding.typed.ShardingEnvelope

object Counter {
  val TypeKey = EntityTypeKey[Command]("counter")

  def init(system: ActorSystem[_]): Unit =
    ClusterSharding(system).init(Entity(TypeKey) { entityContext =>
      Counter(entityContext.entityId)
    })
}

// Usage
val sharding = ClusterSharding(system)
sharding ! ShardingEnvelope("counter-42", Counter.Increment(5))
```

## Custom Mailbox Configuration

```hocon
# application.conf
my-dispatcher {
  type = Dispatcher
  executor = "thread-pool-executor"
  thread-pool-executor {
    fixed-pool-size = 10
  }
  throughput = 100
}

# Pinned dispatcher (one thread per actor)
pinned-dispatcher {
  type = PinnedDispatcher
  executor = "thread-pool-executor"
}

# Bulk mailbox for high throughput
bulk-mailbox {
  mailbox-type = "akka.dispatch.BoundedMailbox"
  mailbox-capacity = 1000
  mailbox-push-timeout-time = 10s
}
```

```scala
// Use custom dispatcher
val actor = context.spawn(
  Behaviors.supervise(MyActor()).onFailure[Exception](SupervisorStrategy.restart),
  "my-actor",
  DispatcherSelector.fromConfig("my-dispatcher")
)
```

## Persistence Snapshotting

```scala
import akka.persistence.typed.scaladsl.{EventSourcedBehavior, SnapshotSelectionCriteria}

object SnapshottedActor {
  def apply(id: String): Behavior[Command] =
    EventSourcedBehavior[Command, Event, State](
      persistenceId = PersistenceId.ofUniqueId(id),
      emptyState = State(),
      commandHandler = ???,
      eventHandler = ???
    ).snapshotEvery(100) // Snapshot every 100 events
      .withSnapshotSelectionCriteria(
        SnapshotSelectionCriteria.latest
      )
      .receiveSignal {
        case (state, RecoveryCompleted) =>
          // Called after recovery completes
      }
}
```

## Akka HTTP Integration

```scala
import akka.actor.typed.scaladsl.Behaviors
import akka.actor.typed.{ActorSystem, Signal}
import akka.http.scaladsl.Http
import akka.http.scaladsl.server.Directives._

object AkkaHttpServer {
  def routes: Behavior[Nothing] = Behaviors.setup { context =>
    implicit val system: ActorSystem[Nothing] = context.system

    val route = get {
      path("hello") {
        complete("Hello from Akka HTTP!")
      }
    }

    val bindingFuture = Http().newServerAt("localhost", 8080).bind(route)

    Behaviors.receiveSignal {
      case (_, Signal.PostStop) =>
        bindingFuture.foreach(_.unbind())(system.executionContext)
        Behaviors.same
      case _ => Behaviors.same
    }
  }
}
```

## MongoDB Integration

```scala
import akka.actor.typed.{ActorRef, Behavior}
import com.mongodb.scala.bson.Document

object MongoActor {
  sealed trait Command
  case class Insert(doc: Document, replyTo: ActorRef[Boolean]) extends Command
  case class Find(filter: Document, replyTo: ActorRef[List[Document]]) extends Command

  def apply(): Behavior[Command] = Behaviors.setup { context =>
    val collection = new MongoClient().getDatabase("mydb").getCollection("items")

    Behaviors.receiveMessage {
      case Insert(doc, replyTo) =>
        context.pipeToSelf(collection.insertOne(doc).toFuture()) {
          case scala.util.Success(_) => true
          case scala.util.Failure(_) => false
        }
        Behaviors.same

      case Find(filter, replyTo) =>
        context.pipeToSelf(collection.find(filter).collect().toFuture()) {
          case scala.util.Success(docs) => docs.toList
          case scala.util.Failure(_) => List.empty
        }
        Behaviors.same
    }
  }
}
```

## Performance Considerations

1. **Dispatcher Configuration**: Use separate dispatchers for blocking vs non-blocking actors
2. **Mailbox Types**: Use bounded mailboxes to prevent memory issues under load
3. **Stream Buffer Size**: Configure appropriate buffer sizes for backpressure
4. **Actor Pooling**: Use `Pool` routers for high-throughput scenarios
5. **Persistence Snapshotting**: Enable periodic snapshotting to reduce recovery time
6. **Cluster Sharding**: Use sharding for even distribution of actors across nodes
