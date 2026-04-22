# Tagless Final Reference

Complete reference for tagless final encoding, capability traits, and interpreter patterns.

## Capability Trait Derivation

### Generic Capability Traits

```scala
trait Clock[F[_]] {
  def currentTimeMillis: F[Long]
  def currentTime: F[Instant]
}

object Clock {
  def apply[F[_]: Sync]: Clock[F] = new Clock[F] {
    def currentTimeMillis: F[Long] = Sync[F].delay(System.currentTimeMillis())
    def currentTime: F[Instant] = Sync[F].delay(Instant.now())
  }
}

trait Random[F[_]] {
  def nextInt(bound: Int): F[Int]
}

object Random {
  def apply[F[_]: Sync]: Random[F] = new Random[F] {
    def nextInt(bound: Int): F[Int] = Sync[F].delay(new scala.util.Random().nextInt(bound))
  }
}
```

### Generic Interpreter Derivation

```scala
class GenericInterpreter[F[_]: Functor](
  userRepo: UserRepository[F],
  emailRepo: EmailService[F],
  clock: Clock[F]
) {
  def findById(id: UserId): F[Option[User]] = userRepo.find(id)
  def sendEmail(to: Email, subject: String): F[Unit] = emailRepo.send(to, subject, "")
  def getCurrentTime: F[Instant] = clock.currentTime
}
```

## Context Passing

```scala
trait RequestContext[F[_]] {
  def getUserId: F[Option[UserId]]
  def getTenantId: F[Option[TenantId]]
  def getCorrelationId: F[CorrelationId]
}

object RequestContext {
  def forRequest[F[_]: Sync](
    userId: Option[UserId] = None,
    tenantId: Option[TenantId] = None,
    correlationId: CorrelationId = CorrelationId.generate()
  ): RequestContext[F] = new RequestContext[F] {
    def getUserId: F[Option[UserId]] = Sync[F].delay(userId)
    def getTenantId: F[Option[TenantId]] = Sync[F].delay(tenantId)
    def getCorrelationId: F[CorrelationId] = Sync[F].delay(correlationId)
  }
}
```

## Recursive Capability Traits

```scala
trait Aggregate[F[_], ID] {
  def load(id: ID): F[AggregateRoot[ID]]
  def persist(root: AggregateRoot[ID]): F[Unit]
}

trait DomainService[F[_]] {
  def createAggregate(id: ID, data: CreateData): F[Aggregate[ID]]
  def updateAggregate(id: ID, data: UpdateData): F[Aggregate[ID]]
}

def processDomainEvent[F[_]: Aggregate: DomainService](
  id: ID, event: DomainEvent
): F[Unit] = for {
  root <- Aggregate[F].load(id)
  updated <- DomainService[F].processEvent(root, event)
  _ <- Aggregate[F].persist(updated)
} yield ()
```

## Composite Pattern

```scala
trait Component[F[_]] {
  def process(input: Input): F[Output]
}

trait LoggingComponent[F[_]] extends Component[F] {
  def process(input: Input): F[Output] = for {
    _ <- Sync[F].delay(println(s"Processing: $input"))
    result <- super.process(input)
    _ <- Sync[F].delay(println(s"Result: $result"))
  } yield result
}

trait ValidationComponent[F[_]] extends Component[F] {
  def process(input: Input): F[Output] = for {
    validated <- validateInput(input)
    result <- super.process(validated)
  } yield result
}

trait CompositeComponent[F[_]: Monad] extends LoggingComponent[F] with ValidationComponent[F]
```

## Higher-Kinded Repository

```scala
trait GenericRepository[F[_], T, ID] {
  def find(id: ID): F[Option[T]]
  def save(entity: T): F[T]
  def delete(id: ID): F[Unit]
  def list(offset: Long, limit: Long): F[List[T]]
}

trait GenericEventHandler[F[_], E] {
  def handle(event: E): F[Unit]
  def handleError(error: Throwable, event: E): F[Unit]
}
```
