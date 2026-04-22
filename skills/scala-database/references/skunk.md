# Skunk — Functional PostgreSQL Client Reference

Skunk is a purely functional PostgreSQL client for Scala, built on cats-effect, fs2, and scodec. It communicates directly with PostgreSQL via its wire protocol — no JDBC involved. This reference covers the full API surface needed for production use.

All examples assume these imports:

```scala
import cats.effect.*
import cats.syntax.all.*
import fs2.Stream
import skunk.*
import skunk.codec.all.*
import skunk.implicits.*
import natchez.Trace.Implicits.noop
```

---

## 1. Session Management

A `Session[F]` represents a single connection to PostgreSQL. Sessions are `Resource` values — they are acquired before use and released (returned to pool or closed) after.

### Session.single — One-off Connection

Creates a single, non-pooled connection. Good for scripts and simple apps.

```scala
val session: Resource[IO, Session[IO]] =
  Session.single(
    host     = "localhost",
    port     = 5432,
    user     = "postgres",
    database = "mydb",
    password = Some("secret")
  )

// Usage — session is automatically closed after use
val program: IO[List[String]] =
  session.use { s =>
    s.execute(sql"SELECT name FROM users".query(varchar))
  }
```

### Session.pooled — Connection Pool

Creates a pool of sessions. Essential for web services and concurrent workloads.

```scala
val pool: Resource[IO, Resource[IO, Session[IO]]] =
  Session.pooled(
    host     = "localhost",
    port     = 5432,
    user     = "postgres",
    database = "mydb",
    password = Some("secret"),
    max      = 10  // maximum number of concurrent connections
  )

// Usage — outer resource is the pool itself, inner is a session from the pool
val program: IO[List[String]] =
  pool.use { sess =>
    sess.use { s =>
      s.execute(sql"SELECT name FROM users".query(varchar))
    }
  }
```

### Session.fromConnectionString

Construct a session from a PostgreSQL connection string.

```scala
val session: Resource[IO, Session[IO]] =
  Session.fromConnectionString[IO](
    "postgresql://postgres:secret@localhost:5432/mydb"
  )
```

### SSL Configuration

Skunk supports TLS via fs2. Use the `ssl` parameter for encrypted connections.

```scala
// Trust all certificates (dev/self-signed)
val session: Resource[IO, Session[IO]] =
  Session.single(
    host     = "localhost",
    user     = "postgres",
    database = "mydb",
    password = Some("secret"),
    ssl      = SSL.Trusted
  )

// System default SSLContext (production with CA-signed certs)
val sessionProd: Resource[IO, Session[IO]] =
  Session.single(
    host     = "db.example.com",
    user     = "app_user",
    database = "mydb",
    password = Some("secret"),
    ssl      = SSL.System
  )
```

Available SSL modes: `SSL.None` (default), `SSL.Trusted`, `SSL.System`, `SSL.fromSSLContext(...)`, `SSL.fromKeyStoreFile(...)`.

### Session Parameters

Skunk sets several session parameters during startup negotiation. Override them if needed (e.g., for Amazon Redshift compatibility):

```scala
val session: Resource[IO, Session[IO]] =
  Session.single(
    host       = "localhost",
    user       = "postgres",
    database   = "mydb",
    password   = Some("secret"),
    parameters = Session.DefaultConnectionParameters - "IntervalStyle"
  )
```

To limit statement execution time, set `statement_timeout`:

```scala
val session: Resource[IO, Session[IO]] =
  Session.single(
    host       = "localhost",
    user       = "postgres",
    database   = "mydb",
    password   = Some("secret"),
    parameters = Session.DefaultConnectionParameters + ("statement_timeout" -> "5000")
  )
```

---

## 2. Codecs

Codecs are the core abstraction in Skunk — they define the mapping between PostgreSQL types and Scala types. A `Codec[A]` is both an `Encoder[A]` (Scala → Postgres) and a `Decoder[A]` (Postgres → Scala).

### Built-in Codecs

All codecs are available via `import skunk.codec.all._`.

**Numeric types:**

| Postgres Type | Codec | Scala Type |
|--------------|-------|------------|
| `int2` / `smallint` | `int2` | `Short` |
| `int4` / `integer` | `int4` | `Int` |
| `int8` / `bigint` | `int8` | `Long` |
| `float4` / `real` | `float4` | `Float` |
| `float8` / `double precision` | `float8` | `Double` |
| `numeric(p,s)` | `numeric(p,s)` | `BigDecimal` |

**Character types:**

| Postgres Type | Codec | Scala Type |
|--------------|-------|------------|
| `varchar(n)` | `varchar` / `varchar(n)` | `String` |
| `bpchar(n)` / `char(n)` | `bpchar(n)` | `String` |
| `text` | `text` | `String` |

**Date/time types:**

| Postgres Type | Codec | Scala Type |
|--------------|-------|------------|
| `date` | `date` | `java.time.LocalDate` |
| `time` | `time` | `java.time.LocalTime` |
| `timetz` | `timetz` | `java.time.OffsetTime` |
| `timestamp` | `timestamp` | `java.time.LocalDateTime` |
| `timestamptz` | `timestamptz` | `java.time.OffsetDateTime` |
| `interval` | `interval` | `java.time.Duration` |

**Other types:**

| Postgres Type | Codec | Scala Type |
|--------------|-------|------------|
| `bool` / `boolean` | `bool` | `Boolean` |
| `uuid` | `uuid` | `java.util.UUID` |
| `bytea` | `bytea` | `Array[Byte]` |
| `json` | `json` | `io.circe.Json` (requires `skunk-circe`) |
| `jsonb` | `jsonb` | `io.circe.Json` (requires `skunk-circe`) |

### Nullable Columns — `.opt`

By default, codecs assume NOT NULL. For nullable columns, use `.opt` to get `Codec[Option[A]]`:

```scala
// For a column defined as: middle_name VARCHAR NULL
val middleName: Codec[Option[String]] = varchar.opt

// In a query
sql"SELECT name, middle_name FROM users".query(varchar *: varchar.opt)
// Decodes to (String, Option[String])
```

You must also use `.opt` in encoders for nullable parameters:

```scala
sql"INSERT INTO users (name, middle_name) VALUES ($varchar, ${varchar.opt})".command
// Encodes (String, Option[String])
```

### Codec Composition with `*:`

Combine multiple codecs into a tuple-like structure using `*:` (the Typelevel Twiddles library):

```scala
// Two columns
val two: Codec[String *: Int *: EmptyTuple] = varchar *: int4

// Three columns
val three: Codec[String *: Int *: Boolean *: EmptyTuple] = varchar *: int4 *: bool
```

These composed codecs produce `*:` tuples which are isomorphic to regular tuples on Scala 3:

```scala
// On Scala 3, these are equivalent:
val t1: (String, Int) = "Alice" *: 42 *: EmptyTuple
val t2: (String, Int) = ("Alice", 42)
```

### Mapping to Case Classes — `.to[...]`

The `.to[F]` method maps a twiddle-list codec directly to a case class:

```scala
case class User(id: Long, name: String, email: String)

// Codec automatically maps fields positionally
val userCodec: Codec[User] = (int8 *: varchar *: varchar).to[User]
```

This replaces the older `gimap` method. The case class fields must match the codec structure positionally.

### Manual Mapping — `.map` / `.contramap`

For non-isomorphic mappings (e.g., wrapping in a newtype):

```scala
// Decoder: Postgres → Scala
case class Email(value: String)
val emailDecoder: Decoder[Email] = varchar.map(Email(_))

// Encoder: Scala → Postgres
val emailEncoder: Encoder[Email] = varchar.contramap(_.value)

// Full codec
val emailCodec: Codec[Email] = Codec(vonencoder = emailEncoder, decoder = emailDecoder)
// Or more simply:
val emailCodec2: Codec[Email] = varchar.imap(Email(_))(_.value)
```

### Enum Codecs

Map PostgreSQL `ENUM` types to Scala sealed traits:

```scala
// PostgreSQL: CREATE TYPE user_role AS ENUM ('admin', 'editor', 'viewer')
sealed abstract class UserRole(val label: String)
object UserRole {
  case object Admin   extends UserRole("admin")
  case object Editor  extends UserRole("editor")
  case object Viewer  extends UserRole("viewer")

  val values: List[UserRole] = List(Admin, Editor, Viewer)
  def fromLabel(label: String): Option[UserRole] = values.find(_.label == label)
}

val roleCodec: Codec[UserRole] =
  enum[UserRole](_.label, UserRole.fromLabel, Type("user_role"))
```

With Enumeratum:

```scala
import enumeratum.{Enum, EnumEntry}
import enumeratum.EnumEntry.Lowercase

sealed trait UserRole extends EnumEntry with Lowercase
object UserRole extends Enum[UserRole] {
  case object Admin  extends UserRole
  case object Editor extends UserRole
  case object Viewer extends UserRole
  val values = findValues
}

val roleCodec: Codec[UserRole] = enum(UserRole, Type("user_role"))
```

### JSON Codecs (with skunk-circe)

```scala
// Add dependency: "org.tpolecat" %% "skunk-circe" % "1.0.+"
import io.circe.Json

// Raw JSON
val jsonCodec: Codec[Json] = jsonb

// Typed JSON — requires circe Encoder/Decoder instances
case class Metadata(created: Long, tags: List[String])
// given Encoder[Metadata] = ...
// given Decoder[Metadata] = ...
val metaCodec: Codec[Metadata] = jsonb[Metadata]
```

---

## 3. Queries

A `Query[A, B]` represents a SQL statement that returns rows. `A` is the parameter type (use `Void` for no params), `B` is the row type.

### Simple Queries (no parameters)

Use `Session.execute` for parameterless queries returning small result sets:

```scala
val allUsers: Query[Void, User] =
  sql"SELECT id, name, email FROM users".query(userCodec)

// Direct execution — returns all rows as a List
def findAll(s: Session[IO]): IO[List[User]] =
  s.execute(allUsers)
```

### Parameterized Queries (extended protocol)

Use `Session.prepare` for queries with parameters, large results, or reuse:

```scala
val userById: Query[Long, User] =
  sql"SELECT id, name, email FROM users WHERE id = $int8".query(userCodec)

// Prepare once, use with different parameters
def findById(s: Session[IO], id: Long): IO[Option[User]] =
  s.prepare(userById).use(_.option(id))
```

### Multi-Parameter Queries

Multiple interpolated codecs create tuple parameters:

```scala
val usersByNameAndAge: Query[String *: Int *: EmptyTuple, User] =
  sql"""
    SELECT id, name, email FROM users
    WHERE name LIKE $varchar AND age > $int4
  """.query(userCodec)

// Call with a tuple
def findUsers(s: Session[IO], name: String, minAge: Int): IO[List[User]] =
  s.prepare(usersByNameAndAge).use(_.stream(name *: minAge *: EmptyTuple, 64).compile.toList)
```

### Query Result Methods

`PreparedQuery[A, B]` provides these execution methods:

```scala
val pq: Resource[IO, PreparedQuery[Long, User]] = s.prepare(userById)

// .unique — exactly one row (throws if 0 or 2+)
pq.use(_.unique(42L))           // IO[User]

// .option — zero or one row (throws if 2+)
pq.use(_.option(42L))           // IO[Option[User]]

// .stream — lazy fs2 Stream with chunked fetching
pq.use(_.stream(42L, 64))      // Resource that yields Stream[IO, User]

// .cursor — cursor for manual paging
pq.use(_.cursor(42L).use { c =>
  for {
    page1 <- c.fetch(10)  // IO[List[User]]
    page2 <- c.fetch(10)  // IO[List[User]] — next 10
  } yield page1 ++ page2
})
```

`Session` also provides direct methods for simple queries:

```scala
s.execute(allUsers)        // IO[List[User]]
s.unique(allUsers)         // IO[User] — exactly one
s.option(allUsers)         // IO[Option[User]] — zero or one
```

### Streaming Query Results

Stream results for memory-efficient processing of large datasets:

```scala
def streamUsers(s: Session[IO]): Stream[IO, User] =
  Stream.resource(s.prepare(userById)).flatMap { pq =>
    pq.stream(42L, chunkSize = 256)
  }

// Process and sink
def exportUsers(s: Session[IO]): IO[Unit] =
  streamUsers(s)
    .evalMap(u => IO.println(s"${u.id}: ${u.name}"))
    .compile
    .drain
```

The `chunkSize` parameter controls how many rows are fetched per network round-trip. Larger values use more memory but reduce latency.

### Pipe — Query per Stream Element

Turn a prepared query into an fs2 `Pipe`:

```scala
def findManyUsers(s: Session[IO]): Pipe[IO, Long, User] = {
  val q: Query[Long, User] = sql"SELECT id, name, email FROM users WHERE id = $int8".query(userCodec)
  Stream.resource(s.prepare(q)).flatMap { pq =>
    pq.pipe
  }
}

// Usage: feed user IDs, get Users back
def program(s: Session[IO]): IO[Unit] =
  Stream(1L, 2L, 3L)
    .through(findManyUsers(s))
    .evalMap(u => IO.println(u))
    .compile
    .drain
```

---

## 4. Commands

A `Command[A]` represents a SQL statement that does NOT return rows (INSERT, UPDATE, DELETE, DDL). `A` is the parameter type.

### Simple Commands (no parameters)

```scala
val createTable: Command[Void] =
  sql"""
    CREATE TABLE IF NOT EXISTS users (
      id    BIGSERIAL PRIMARY KEY,
      name  VARCHAR NOT NULL,
      email VARCHAR NOT NULL
    )
  """.command

s.execute(createTable) // IO[Completion]
```

`Completion` is an ADT: `Completion.CreateTable`, `Completion.DropTable`, `Completion.Insert(n)`, `Completion.Update(n)`, `Completion.Delete(n)`, etc.

### Parameterized Commands

```scala
val insertUser: Command[String *: String *: EmptyTuple] =
  sql"INSERT INTO users (name, email) VALUES ($varchar, $varchar)".command

// Execute with parameters
s.prepare(insertUser).use(_.execute("Alice" *: "alice@example.com" *: EmptyTuple))
// IO[Completion] → Completion.Insert(1)
```

### Commands with Case Class Input — `.to[...]`

```scala
case class CreateUser(name: String, email: String)

val insertUser: Command[CreateUser] =
  sql"INSERT INTO users (name, email) VALUES ($varchar, $varchar)".command.to[CreateUser]

s.prepare(insertUser).use(_.execute(CreateUser("Alice", "alice@example.com")))
```

### RETURNING Clause — Command + Query Hybrid

When you need generated values back (like auto-incremented IDs), use `RETURNING` with a `.query` instead of `.command`:

```scala
val insertReturning: Query[String *: String *: EmptyTuple, User] =
  sql"""
    INSERT INTO users (name, email)
    VALUES ($varchar, $varchar)
    RETURNING id, name, email
  """.query(userCodec)

// Use .unique since RETURNING gives exactly one row
s.prepare(insertReturning).use(_.unique("Alice" *: "alice@example.com" *: EmptyTuple))
// IO[User]
```

### Bulk Operations — `.list` and `.values`

Insert multiple rows in a single statement:

```scala
// Fixed-size list encoder
def insertMany(n: Int): Command[List[String *: String *: EmptyTuple]] = {
  val enc = (varchar *: varchar).values.list(n)
  sql"INSERT INTO users (name, email) VALUES $enc".command
}

val insert3 = insertMany(3)
s.prepare(insert3).use(_.execute(
  List("Alice" *: "a@x.com" *: EmptyTuple, "Bob" *: "b@x.com" *: EmptyTuple, "Eve" *: "e@x.com" *: EmptyTuple)
))
```

Safer variant — bind the command to a specific list instance:

```scala
def insertExactly(users: List[CreateUser]): Command[users.type] = {
  val enc = (varchar *: varchar).to[CreateUser].values.list(users)
  sql"INSERT INTO users (name, email) VALUES $enc".command
}

val users = List(CreateUser("Alice", "a@x.com"), CreateUser("Bob", "b@x.com"))
val cmd = insertExactly(users)
// cmd only accepts the exact `users` list — type-safe!
s.prepare(cmd).use(_.execute(users))
```

### IN Clause with `.list`

```scala
def deleteByName(n: Int): Command[List[String]] =
  sql"DELETE FROM users WHERE name IN (${varchar.list(n)})".command

s.prepare(deleteByName(3)).use(_.execute(List("Alice", "Bob", "Eve")))
```

---

## 5. Transactions

Skunk transactions are `Resource` values. The transaction is committed on normal exit and rolled back on error or cancellation.

### Basic Transaction

```scala
def transferFunds(s: Session[IO], from: Long, to: Long, amount: Double): IO[Unit] =
  s.transaction.use { _ =>
    for {
      _ <- s.prepare(sql"UPDATE accounts SET balance = balance - $float8 WHERE id = $int8".command)
            .use(_.execute(amount *: from *: EmptyTuple))
      _ <- s.prepare(sql"UPDATE accounts SET balance = balance + $float8 WHERE id = $int8".command)
            .use(_.execute(amount *: to *: EmptyTuple))
    } yield ()
  }
```

### Transaction with Savepoints and Error Recovery

The `xa` parameter provides access to savepoints:

```scala
import skunk.exception.SkunkException

def insertWithRecovery(s: Session[IO], users: List[CreateUser]): IO[Unit] =
  s.transaction.use { xa =>
    users.traverse_ { user =>
      for {
        sp <- xa.savepoint                          // create a savepoint
        _  <- s.prepare(insertUser).use(_.execute(user)).recoverWith {
          case SqlState.UniqueViolation(_) =>
            IO.println(s"Duplicate: ${user.name}, rolling back to savepoint") *>
            xa.rollback(sp)                         // rollback to savepoint, continue
        }
      } yield ()
    }
  }
```

### Transaction Isolation Levels

```scala
import skunk.data.TransactionIsolationLevel
import skunk.data.TransactionAccessMode

s.transaction(
  isolationLevel = TransactionIsolationLevel.Serializable,
  accessMode     = TransactionAccessMode.ReadOnly
).use { _ =>
  // read-only serializable transaction
  s.execute(sql"SELECT count(*) FROM users".query(int8))
}
```

Available isolation levels: `ReadCommitted` (default), `RepeatableRead`, `Serializable`.
Available access modes: `ReadWrite` (default), `ReadOnly`.

### Monitoring Transaction Status

```scala
// TransactionStatus is available as an fs2 Signal
def logTransactionStatus(s: Session[IO]): IO[Unit] =
  s.transactionStatus.discrete
    .evalMap(status => IO.println(s"Transaction status: $status"))
    .compile
    .drain
```

Status values: `Idle`, `Active`, `Error` (failed transaction, must rollback).

---

## 6. Streaming

Skunk's streaming is built directly on fs2, with natural backpressure from chunked fetching.

### Basic Streaming

```scala
def streamAllUsers(s: Session[IO]): Stream[IO, User] = {
  val q = sql"SELECT id, name, email FROM users".query(userCodec)
  Stream.resource(s.prepare(q)).flatMap(_.stream(Void, chunkSize = 256))
}
```

### Streaming with Parameters

```scala
def streamUsersByName(s: Session[IO], pattern: String): Stream[IO, User] = {
  val q = sql"SELECT id, name, email FROM users WHERE name LIKE $varchar".query(userCodec)
  Stream.resource(s.prepare(q)).flatMap(_.stream(pattern, 64))
}
```

### Streaming from a Pooled Session

```scala
def allUsersStream: Stream[IO, User] =
  Stream.resource(pool).flatMap { sess =>
    Stream.resource(sess).flatMap { s =>
      Stream.resource(s.prepare(sql"SELECT id, name, email FROM users".query(userCodec)))
        .flatMap(_.stream(Void, 256))
    }
  }
```

### Processing Streams

```scala
// Transform and sink
def exportToCsv(s: Session[IO]): IO[Unit] =
  streamAllUsers(s)
    .map(u => s"${u.id},${u.name},${u.email}")
    .through(fs2.text.lines)
    .through(fs2.io.writeLines(Paths.get("users.csv")))
    .compile
    .drain

// Batch processing
def processBatches(s: Session[IO]): IO[Unit] =
  streamAllUsers(s)
    .chunkN(100)
    .evalMap { chunk =>
      // process 100 users at a time
      IO.println(s"Processing batch of ${chunk.size} users")
    }
    .compile
    .drain
```

---

## 7. Error Handling

Skunk errors are structured and carry PostgreSQL diagnostic information.

### Error Hierarchy

```
SkunkException
├── PostgresErrorException     — Server returned an error (SQLSTATE-based)
├── UnexpectedRowsException    — Query returned unexpected number of rows
├── ColumnAlignmentException   — Column count mismatch
├── DecodeException            — Failed to decode a row value
└── ...
```

### Handling Unique Violations

```scala
import skunk.exception.SkunkException
import skunk.codec.all.*

def insertUserSafe(s: Session[IO], name: String, email: String): IO[Either[String, User]] =
  s.prepare(sql"""
    INSERT INTO users (name, email) VALUES ($varchar, $varchar)
    RETURNING id, name, email
  """.query(userCodec))
    .use(_.unique(name *: email *: EmptyTuple))
    .map(Right(_))
    .recoverWith {
      case SqlState.UniqueViolation(ex) =>
        IO.pure(Left(s"Duplicate entry: ${ex.constraintName.getOrElse("unknown")}"))
    }
```

### SqlState Pattern Matching

`SqlState` provides an extractor for common PostgreSQL error codes:

```scala
recoverWith {
  case SqlState.UniqueViolation(ex)        => ...  // 23505
  case SqlState.ForeignKeyViolation(ex)     => ...  // 23503
  case SqlState.CheckViolation(ex)          => ...  // 23514
  case SqlState.NotNullViolation(ex)        => ...  // 23502
  case SqlState.UndefinedTable(ex)          => ...  // 42P01
  case SqlState.SyntaxError(ex)             => ...  // 42601
}
```

Each extractor provides access to the full `PostgresErrorException`, which includes: `sql`, `sqlOrigin`, `message`, `detail`, `hint`, `schemaName`, `tableName`, `columnName`, `constraintName`.

### Generic Error Handling

```scala
sealed trait DatabaseError
case class NotFound(entity: String, id: Long)      extends DatabaseError
case class UniqueViolation(constraint: String)      extends DatabaseError
case class ConnectionError(message: String)          extends DatabaseError
case class UnexpectedError(message: String)          extends DatabaseError

def findUserSafe(s: Session[IO], id: Long): IO[Either[DatabaseError, User]] =
  s.prepare(sql"SELECT id, name, email FROM users WHERE id = $int8".query(userCodec))
    .use(_.option(id))
    .map {
      case Some(u) => Right(u)
      case None    => Left(NotFound("User", id))
    }
    .recoverWith {
      case SqlState.UniqueViolation(ex) =>
        IO.pure(Left(UniqueViolation(ex.constraintName.getOrElse("unknown"))))
      case e: SkunkException =>
        IO.pure(Left(UnexpectedError(e.message)))
    }
```

---

## 8. Fragment Composition

Fragments allow building dynamic SQL queries programmatically, similar to doobie's `Fragment`.

### The `sql` Interpolator

```scala
// Fragment with no parameters
val f1: Fragment[Void] = sql"SELECT 42"

// Fragment with one parameter
val f2: Fragment[Long] = sql"SELECT * FROM users WHERE id = $int8"

// Fragment with multiple parameters
val f3: Fragment[String *: Int *: EmptyTuple] =
  sql"SELECT * FROM users WHERE name = $varchar AND age > $int4"
```

### Composing Fragments with `*:`

```scala
val base: Fragment[Void] = sql"SELECT id, name, email FROM users"

val byName: Fragment[String]    = sql"name LIKE $varchar"
val byAge: Fragment[Int]        = sql"age > $int4"
val activeOnly: Fragment[Void]  = sql"active = true"

// Combine: SELECT ... FROM users WHERE name LIKE $1 AND age > $2
val combined: Fragment[String *: Int *: EmptyTuple] = base *: sql" WHERE " *: byName *: sql" AND " *: byAge
```

### Applied Fragments — Dynamic Query Building

`AppliedFragment` binds a fragment to its arguments, forming a monoid for composing dynamic queries:

```scala
def userQuery(
  nameFilter: Option[String],
  minAge: Option[Int],
  activeOnly: Boolean
): AppliedFragment = {
  val base = sql"SELECT id, name, email FROM users"

  val conds: List[AppliedFragment] = List(
    nameFilter.map(n => sql"name LIKE $varchar".apply(n)),
    minAge.map(a => sql"age > $int4".apply(a)),
    Option.when(activeOnly)(sql"active = true".apply(Void))
  ).flatten

  val filter =
    if (conds.isEmpty) AppliedFragment.empty
    else conds.foldSmash(void" WHERE ", void" AND ", AppliedFragment.empty)

  base(Void) |+| filter
}

// Usage
def findUsers(s: Session[IO], name: Option[String], minAge: Option[Int], activeOnly: Boolean): IO[List[User]] = {
  val af = userQuery(name, minAge, activeOnly)
  s.prepare(af.fragment.query(userCodec)).use(_.stream(af.argument, 64).compile.toList)
}
```

### Literal String Interpolation — `#$`

For table/column names that can't be parameters (SQL injection risk — never use with user input):

```scala
val tableName = "users"
val frag = sql"SELECT * FROM #$tableName WHERE id = $int8"
// SQL: SELECT * FROM users WHERE id = $1
```

### Fragment Utilities

```scala
// Void fragments for keywords
void"WHERE"       // Fragment[Void] containing "WHERE"
void" AND "       // Fragment[Void] containing " AND "

// .contramap — change input type
val insertFrag: Fragment[String *: String *: EmptyTuple] =
  sql"INSERT INTO users (name, email) VALUES ($varchar, $varchar)"

val mappedFrag: Fragment[CreateUser] =
  insertFrag.contramap(u => u.name *: u.email *: EmptyTuple)

// .to[F] — automatic case class mapping
val caseClassFrag: Fragment[CreateUser] =
  sql"INSERT INTO users (name, email) VALUES ($varchar, $varchar)".to[CreateUser]
```

---

## 9. Connection Pooling

### Session.pooled

```scala
val pool: Resource[IO, Resource[IO, Session[IO]]] =
  Session.pooled(
    host     = "localhost",
    port     = 5432,
    user     = "postgres",
    database = "mydb",
    password = Some("secret"),
    max      = 10,      // max concurrent connections
    debug    = false    // log SQL to stdout (useful in dev)
  )
```

### Pool Lifecycle

The outer `Resource` manages the pool itself. The inner `Resource` checks out a session:

```scala
object MyApp extends IOApp.Simple {
  val pool: Resource[IO, Resource[IO, Session[IO]]] =
    Session.pooled(host = "localhost", user = "postgres", database = "mydb", password = Some("secret"), max = 10)

  val run: IO[Unit] =
    pool.use { sessionResource =>
      // Each request in a web app would get its own session:
      sessionResource.use { s =>
        for {
          count <- s.unique(sql"SELECT count(*) FROM users".query(int8))
          _     <- IO.println(s"Total users: $count")
        } yield ()
      }
    }
}
```

### Debug Mode

Enable debug logging to see all SQL statements sent to PostgreSQL:

```scala
Session.single(
  host     = "localhost",
  user     = "postgres",
  database = "mydb",
  password = Some("secret"),
  debug    = true  // prints all SQL to stdout
)
```

---

## 10. Repository Pattern with Skunk

The service/repository pattern wraps session operations behind a type-safe interface, keeping database details out of business logic.

### Tagless Final Repository

```scala
case class User(id: Long, name: String, email: String)
case class CreateUser(name: String, email: String)

trait UserRepository[F[_]] {
  def findAll: F[List[User]]
  def findById(id: Long): F[Option[User]]
  def create(user: CreateUser): F[User]
  def update(id: Long, name: String): F[Unit]
  def delete(id: Long): F[Unit]
}

object UserRepository {

  // Private query/command definitions — kept close to the repository
  private val userCodec: Codec[User] =
    (int8 *: varchar *: varchar).to[User]

  private val selectAll: Query[Void, User] =
    sql"SELECT id, name, email FROM users".query(userCodec)

  private val selectById: Query[Long, User] =
    sql"SELECT id, name, email FROM users WHERE id = $int8".query(userCodec)

  private val insertQuery: Query[String *: String *: EmptyTuple, User] =
    sql"INSERT INTO users (name, email) VALUES ($varchar, $varchar) RETURNING id, name, email".query(userCodec)

  private val updateCmd: Command[String *: Long *: EmptyTuple] =
    sql"UPDATE users SET name = $varchar WHERE id = $int8".command

  private val deleteCmd: Command[Long] =
    sql"DELETE FROM users WHERE id = $int8".command

  // Constructor — prepares statements once for efficiency
  def fromSession[F[_]: MonadError[*[_], Throwable]](s: Session[F]): F[UserRepository[F]] =
    for {
      pSelectById <- s.prepare(selectById)
      pInsert     <- s.prepare(insertQuery)
      pUpdate     <- s.prepare(updateCmd)
      pDelete     <- s.prepare(deleteCmd)
    } yield new UserRepository[F] {
      def findAll: F[List[User]]                = s.execute(selectAll)
      def findById(id: Long): F[Option[User]]   = pSelectById.option(id)
      def create(user: CreateUser): F[User]     = pInsert.unique(user.name *: user.email *: EmptyTuple)
      def update(id: Long, name: String): F[Unit] = pUpdate.execute(name *: id *: EmptyTuple).void
      def delete(id: Long): F[Unit]             = pDelete.execute(id).void
    }
}
```

### Service-Oriented Architecture

Hide the database behind a service trait so business logic sees no SQL:

```scala
trait UserService[F[_]] {
  def listUsers: F[List[User]]
  def getUser(id: Long): F[Option[User]]
  def register(name: String, email: String): F[Either[String, User]]
  def rename(id: Long, newName: String): F[Unit]
}

object UserService {
  def fromSession[F[_]: MonadError[*[_], Throwable]](s: Session[F]): F[UserService[F]] =
    UserRepository.fromSession[F](s).map { repo =>
      new UserService[F] {
        def listUsers: F[List[User]] = repo.findAll

        def getUser(id: Long): F[Option[User]] = repo.findById(id)

        def register(name: String, email: String): F[Either[String, User]] =
          repo.create(CreateUser(name, email))
            .map(Right(_))
            .recoverWith {
              case SqlState.UniqueViolation(_) =>
                MonadError[F, Throwable].pure(Left(s"Email $email already registered"))
            }

        def rename(id: Long, newName: String): F[Unit] = repo.update(id, newName)
      }
    }
}

// Application entry point
object Main extends IOApp.Simple {
  val session: Resource[IO, Session[IO]] =
    Session.single(host = "localhost", user = "postgres", database = "mydb", password = Some("secret"))

  val run: IO[Unit] =
    session.evalMap(UserService.fromSession[IO]).use { service =>
      for {
        result <- service.register("Alice", "alice@example.com")
        _      <- IO.println(result)
        users  <- service.listUsers
        _      <- users.traverse_(u => IO.println(s"${u.id}: ${u.name}"))
      } yield ()
    }
}
```

### Wired with a Pool

```scala
object PooledApp extends IOApp.Simple {
  val pool: Resource[IO, Resource[IO, Session[IO]]] =
    Session.pooled(host = "localhost", user = "postgres", database = "mydb", password = Some("secret"), max = 10)

  val run: IO[Unit] =
    pool.use { sessionResource =>
      // Simulate handling many requests
      (1 to 50).toList.traverse_ { _ =>
        sessionResource.use { s =>
          UserService.fromSession[IO](s).flatMap { service =>
            service.listUsers.flatMap(_.traverse_(u => IO.println(u.name)))
          }
        }
      }
    }
```

---

## Appendix: Quick Reference

### Session Creation

| Method | Use Case |
|--------|----------|
| `Session.single(...)` | Single connection, scripts, tests |
| `Session.pooled(...)` | Connection pool, web services |
| `Session.fromConnectionString(...)` | URI-based config |

### Query Execution

| Method | Returns | Notes |
|--------|---------|-------|
| `s.execute(q)` | `F[List[A]]` | Simple queries only |
| `s.unique(q)` | `F[A]` | Exactly one row |
| `s.option(q)` | `F[Option[A]]` | Zero or one row |
| `s.prepare(q).use(_.option(a))` | `F[Option[A]]` | Extended query |
| `s.prepare(q).use(_.unique(a))` | `F[A]` | Extended, one row |
| `s.prepare(q).use(_.stream(a, n))` | `Stream[F, A]` | Streaming results |
| `s.prepare(q).use(_.cursor(a))` | `Resource[F, Cursor]` | Manual paging |

### Codec Combinators

| Combinator | Effect |
|-----------|--------|
| `a *: b` | Compose codecs into tuple |
| `.to[Foo]` | Map to case class |
| `.opt` | Nullable column (`Codec[Option[A]]`) |
| `.imap(f)(g)` | Bidirectional mapping |
| `.contramap(f)` | Map encoder input |
| `.map(f)` | Map decoder output |
| `.values` | Wrap SQL in parentheses |
| `.list(n)` | Repeat n times for batch ops |

### Error Extractors

| Extractor | SQLSTATE | Meaning |
|-----------|----------|---------|
| `SqlState.UniqueViolation` | 23505 | Duplicate key |
| `SqlState.ForeignKeyViolation` | 23503 | FK constraint |
| `SqlState.NotNullViolation` | 23502 | NULL in NOT NULL column |
| `SqlState.CheckViolation` | 23514 | CHECK constraint |
| `SqlState.SyntaxError` | 42601 | SQL syntax error |
| `SqlState.UndefinedTable` | 42P01 | Table not found |
