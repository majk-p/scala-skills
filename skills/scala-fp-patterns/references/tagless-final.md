# Tagless Final Reference

Complete reference for tagless final encoding: capability traits, interpreters, testing, multi-algebra composition, and effect polymorphism tradeoffs.

## Capability Trait Derivation

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

## Composite Pattern

```scala
trait Component[F[_]] { def process(input: Input): F[Output] }

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
```

## Complete End-to-End Example

Full application: algebra → doobie interpreter → in-memory test interpreter → business logic → wiring.

### Domain & Algebras

```scala
case class ItemId(value: Long) extends AnyVal
case class OrderId(value: Long) extends AnyVal
case class Item(id: ItemId, name: String, price: BigDecimal, inStock: Boolean)
case class OrderItem(itemId: ItemId, quantity: Int, unitPrice: BigDecimal)
case class Order(id: OrderId, userId: UserId, items: List[OrderItem], total: BigDecimal)

sealed trait OrderError
case class ItemNotFound(itemId: ItemId) extends OrderError
case class ItemOutOfStock(itemId: ItemId) extends OrderError

trait Items[F[_]] {
  def findById(id: ItemId): F[Option[Item]]
  def updateStock(id: ItemId, delta: Int): F[Unit]
}

trait Orders[F[_]] {
  def create(order: Order): F[Order]
  def findByUser(userId: UserId): F[List[Order]]
}

trait OrderIdGen[F[_]] { def nextId: F[OrderId] }
```

### Business Logic (Effect-Polymorphic)

```scala
class OrderService[F[_]: Monad: Items: Orders: OrderIdGen] {
  def placeOrder(userId: UserId, lineItems: List[(ItemId, Int)]): EitherT[F, OrderError, Order] =
    for {
      items <- lineItems.traverse { case (id, qty) =>
        EitherT.fromOptionF(Items[F].findById(id), ItemNotFound(id): OrderError).map(_ -> qty)
      }
      _ <- items.traverse_ { case (item, _) =>
        EitherT.cond[F](item.inStock, (), ItemOutOfStock(item.id): OrderError)
      }
      orderItems = items.map { case (item, qty) => OrderItem(item.id, qty, item.price) }
      total = orderItems.map(i => i.unitPrice * i.quantity).combineAll
      id <- EitherT.liftF(OrderIdGen[F].nextId)
      order = Order(id, userId, orderItems, total)
      _ <- EitherT.liftF(Orders[F].create(order))
      _ <- EitherT.liftF(items.traverse_ { case (item, qty) => Items[F].updateStock(item.id, -qty) })
    } yield order
}
```

### Production Interpreter (Doobie)

```scala
object DoobieItems {
  def impl[F[_]: Sync](xa: Transactor[F]): Items[F] = new Items[F] {
    def findById(id: ItemId): F[Option[Item]] =
      sql"SELECT id, name, price, in_stock FROM items WHERE id = ${id.value}"
        .query[Item].option.transact(xa)
    def updateStock(id: ItemId, delta: Int): F[Unit] =
      sql"UPDATE items SET stock = stock + $delta WHERE id = ${id.value}"
        .update.run.transact(xa).void
  }
}
```

### Test Interpreter (In-Memory)

```scala
object InMemoryItems {
  def impl[F[_]: Sync]: F[Items[F]] =
    Ref.of[F, Map[ItemId, Item]](Map.empty).map { ref =>
      new Items[F] {
        def findById(id: ItemId): F[Option[Item]] = ref.get.map(_.get(id))
        def updateStock(id: ItemId, delta: Int): F[Unit] =
          ref.update(_.updatedWith(id)(_.map(_.copy(inStock = true))))
      }
    }

  def withData[F[_]: Sync](initial: Map[ItemId, Item]): F[Items[F]] =
    Ref.of[F, Map[ItemId, Item]](initial).map { ref =>
      new Items[F] {
        def findById(id: ItemId): F[Option[Item]] = ref.get.map(_.get(id))
        def updateStock(id: ItemId, delta: Int): F[Unit] =
          ref.update(_.updatedWith(id)(_.map(_.copy(inStock = true))))
      }
    }
}
```

### Application Wiring

```scala
object Main extends IOApp.Simple {
  def run: IO[Unit] = transactor.use { xa =>
    implicit val items: Items[IO] = DoobieItems.impl(xa)
    implicit val orders: Orders[IO] = DoobieOrders.impl(xa)
    implicit val idGen: OrderIdGen[IO] = counterIdGen[IO]

    val service = new OrderService[IO]
    service.placeOrder(UserId(1), List(ItemId(42) -> 2)).value.flatMap {
      case Right(o) => IO.println(s"Created: $o")
      case Left(e)  => IO.println(s"Failed: $e")
    }
  }
}
```

## Testing Tagless Final Services

### Unit Tests with In-Memory Interpreters

```scala
class OrderServiceSpec extends FunSuite {
  def withService[A](test: OrderService[IO] => IO[A]): A = {
    (for {
      items <- InMemoryItems.withData[IO](Map(
        ItemId(1) -> Item(ItemId(1), "Widget", BigDecimal(9.99), inStock = true),
        ItemId(2) -> Item(ItemId(2), "Gadget", BigDecimal(24.99), inStock = false)
      ))
      orders <- InMemoryOrders.impl[IO]
    } yield {
      implicit val _items: Items[IO] = items
      implicit val _orders: Orders[IO] = orders
      implicit val _idGen: OrderIdGen[IO] = counterIdGen[IO]
      new OrderService[IO]
    }).flatMap(test).unsafeRunSync()
  }

  test("succeeds when items in stock") {
    withService(_.placeOrder(UserId(1), List(ItemId(1) -> 3)).value.map {
      case Right(o) => assertEquals(o.total, BigDecimal(29.97))
      case Left(e)  => fail(s"Unexpected: $e")
    })
  }

  test("fails when item out of stock") {
    withService(_.placeOrder(UserId(1), List(ItemId(2) -> 1)).value.map {
      case Left(ItemOutOfStock(_)) => ()
      case other => fail(s"Expected ItemOutOfStock, got $other")
    })
  }
}
```

### Minimal Stubs for Focused Tests

```scala
object StubItems {
  def returning[F[_]: Applicative](data: Map[ItemId, Item]): Items[F] = new Items[F] {
    def findById(id: ItemId): F[Option[Item]] = data.get(id).pure[F]
    def updateStock(id: ItemId, delta: Int): F[Unit] = ().pure[F]
  }
}
```

### Property-Based Testing

```scala
implicit val arbItem: Arbitrary[Item] = Arbitrary(for {
  id <- Gen.posNum[Long].map(ItemId(_))
  name <- Gen.alphaStr
  price <- Gen.choose(1, 1000).map(BigDecimal(_))
} yield Item(id, name, price, inStock = true))

val validOrderCreatesOne: Prop = forAll { (item: Item, qty: PosInt) =>
  val (result, history) = (for {
    implicit0(items: Items[IO]) <- InMemoryItems.withData[IO](Map(item.id -> item))
    implicit0(orders: Orders[IO]) <- InMemoryOrders.impl[IO]
    implicit0(idGen: OrderIdGen[IO]) = counterIdGen[IO]
    svc = new OrderService[IO]
    r <- svc.placeOrder(UserId(1), List(item.id -> qty.value)).value
    h <- svc.orderHistory(UserId(1))
  } yield (r, h)).unsafeRunSync()
  result.isRight ==> (history.size == 1)
}
```

## Composing Multiple Algebras

### Explicit Parameter Passing (Recommended)

Clear dependencies, easy to test, no implicit magic:

```scala
class CheckoutService[F[_]: Monad](
  items: Items[F],
  orders: Orders[F],
  payments: Payments[F],
  notifications: Notifications[F]
) {
  def checkout(userId: UserId, lineItems: List[(ItemId, Int)]): EitherT[F, OrderError, Order] =
    for {
      order <- new OrderService[F] {}.placeOrder(userId, lineItems)
      _ <- EitherT.liftF(payments.charge(userId, order.total))
      _ <- EitherT.liftF(notifications.sendConfirmation(userId, order.id))
    } yield order
}
// Wiring: val checkout = new CheckoutService[IO](items, orders, payments, notifs)
```

### Cake Pattern Alternative

Self-type traits for mixin composition — better for large modular codebases, harder to test in isolation:

```scala
trait ItemsModule[F[_]] { val items: Items[F] }
trait OrdersModule[F[_]] { val orders: Orders[F] }
trait PaymentsModule[F[_]] { val payments: Payments[F] }

trait CakeCheckout[F[_]: Monad]
  extends ItemsModule[F] with OrdersModule[F] with PaymentsModule[F] {
  def checkout(userId: UserId, lineItems: List[(ItemId, Int)]): EitherT[F, OrderError, Order] =
    for {
      order <- /* uses items, orders directly */ ???
      _ <- EitherT.liftF(payments.charge(userId, order.total))
    } yield order
}

// Wiring via mixin composition:
object App extends CakeCheckout[IO]
  with ItemsModule[IO] with OrdersModule[IO] with PaymentsModule[IO] {
  val items = DoobieItems.impl(xa)
  val orders = DoobieOrders.impl(xa)
  val payments = StripePayments.impl[IO]
}
```

| Approach | Pros | Cons |
|----------|------|------|
| **Explicit params** | Clear deps, easy to mock | Verbose with 5+ params |
| **Context bounds** | Concise, idiomatic | Implicit scope pollution |
| **Cake pattern** | Large codebase modularity | Boilerplate, linearization issues |

Prefer explicit params for services, context bounds for standalone functions.

## Interpreters for Different Effect Types

Same algebra, four interpreters for different testing/production scenarios:

```scala
trait KeyValueStore[F[_]] {
  def get(key: String): F[Option[String]]
  def put(key: String, value: String): F[Unit]
  def delete(key: String): F[Unit]
}
```

**IO (Production):**

```scala
class IOKeyValueStore(ref: Ref[IO, Map[String, String]]) extends KeyValueStore[IO] {
  def get(key: String): IO[Option[String]] = ref.get.map(_.get(key))
  def put(key: String, value: String): IO[Unit] = ref.update(_ + (key -> value))
  def delete(key: String): IO[Unit] = ref.update(_ - key)
}
```

**Id (Pure Testing — no IO, no unsafeRun):**

```scala
class IdKeyValueStore extends KeyValueStore[Id] {
  private var data = Map.empty[String, String]
  def get(key: String): Id[Option[String]] = data.get(key)
  def put(key: String, value: String): Id[Unit] = { data = data + (key -> value) }
  def delete(key: String): Id[Unit] = { data = data - key }
}
// Usage: val result: Option[String] = store.get("name")  // Some("Alice") — synchronous
```

**Either (Error Testing):**

```scala
sealed trait StoreError
case class KeyExists(key: String) extends StoreError

class EitherKeyValueStore extends KeyValueStore[Either[StoreError, *]] {
  private var data = Map.empty[String, String]
  def get(key: String): Either[StoreError, Option[String]] = Right(data.get(key))
  def put(key: String, value: String): Either[StoreError, Unit] =
    if (data.contains(key)) Left(KeyExists(key))
    else { data = data + (key -> value); Right(()) }
  def delete(key: String): Either[StoreError, Unit] = Right { data = data - key }
}
```

**Writer (Audit Logging):**

```scala
type Audit[A] = Writer[List[String], A]

class AuditedKeyValueStore extends KeyValueStore[Audit] {
  private var data = Map.empty[String, String]
  def get(key: String): Audit[Option[String]] = Writer(List(s"GET $key"), data.get(key))
  def put(key: String, value: String): Audit[Unit] =
    { data = data + (key -> value); Writer(List(s"PUT $key=$value"), ()) }
  def delete(key: String): Audit[Unit] =
    { data = data - key; Writer(List(s"DELETE $key"), ()) }
}
// Extract audit trail: val (log, _) = store.put("k", "v").run
```

## Effect Polymorphism Tradeoffs

### When Tagless Final Adds Value

- **Testability**: In-memory interpreters replace databases, HTTP, filesystem
- **Separation of concerns**: Business logic has zero knowledge of infrastructure
- **Pure testing**: `Id` interpreters let you test without `IO` at all

### The Tagless Final Tax

```scala
// THE TAX: verbose constraints, confusing compiler errors, mental overhead
def logic[F[_]: Monad: Concurrent: Temporal: Items: Orders: Payments: Logging: Clock](
  input: Input
): F[Output] = ???

// Contrast — simpler when polymorphism adds nothing:
def simpleScript(input: Input): IO[Output] = for {
  data <- db.query(input.id)
  result <- transform(data)
  _ <- httpClient.post(result)
} yield result
```

### When to Use IO Directly

1. **Scripts/CLIs** — one interpreter, no testing need
2. **Thin HTTP layers** — controller → service → repo, no swapping
3. **Prototypes** — get it working first, abstract later
4. **Simple pipelines** — sequential transforms, no polymorphism benefit

### Hybrid Approach

Tagless final for core domain (testing matters), IO at edges (glue code):

```scala
// Core — tagless final
class PaymentService[F[_]: Monad: Payments: Ledger] {
  def processPayment(order: Order): EitherT[F, PaymentError, Receipt] = ???
}

// Edge — IO is fine, this is glue
object HttpRoutes {
  def paymentRoute(svc: PaymentService[IO]): HttpRoutes[IO] =
    HttpRoutes.of[IO] { case req @ POST -> Root / "pay" =>
      for {
        order <- req.as[Order]
        result <- svc.processPayment(order).value
        resp <- result.fold(errorToResponse, okResponse)
      } yield resp
    }
}
```

### Decision Framework

```
Will you test with a different interpreter?
├── YES → Tagless final
│   └── >3 algebras? Use explicit params, not context bounds
└── NO
    ├── Infrastructure wiring / glue? → IO directly
    └── Core business logic? → Tagless final (you'll want tests later)
```
