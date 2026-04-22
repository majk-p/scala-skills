---
name: scala-database
description: Use this skill when working with databases functionally in Scala using doobie. Covers type-safe SQL queries, connection management, CRUD operations, transactions, query composition with fragments, custom type mappings, repository patterns, advanced error handling, and performance optimization. Trigger when the user mentions database operations, SQL queries, JDBC, transactions, connection pooling, doobie, or needs to interact with relational databases using functional programming patterns.
---

# Functional Database Access with Doobie

Doobie provides type-safe, pure functional JDBC access built on cats-effect and fs2. All database operations are expressed as `ConnectionIO[A]` values that compose via for-comprehensions and transact against a `Transactor`.

## Quick Start

```scala
import doobie._
import doobie.implicits._
import cats.effect.IO

// Basic transactor setup with HikariCP
val xa = Transactor.fromDriverManager[IO](
  driver = "org.postgresql.Driver",
  url = "jdbc:postgresql:world",
  user = "postgres",
  password = "password"
)
```

## Core Concepts

### ConnectionIO and Queries

```scala
case class User(id: Long, name: String, email: String)

// Simple select query
def findUserById(id: Long): ConnectionIO[Option[User]] =
  sql"select id, name, email from users where id = $id".query[User].option

// Execute query
val result: IO[Option[User]] = findUserById(1L).transact(xa)
```

### Connection Pooling

```scala
import doobie.hikari._
import com.zaxxer.hikari.HikariConfig

val config = new HikariConfig()
config.setMaximumPoolSize(10)
config.setConnectionTimeout(30000)

val xa: Resource[IO, HikariTransactor[IO]] =
  HikariTransactor.fromHikariConfig[IO](config)
```

## CRUD Operations

### Create

```scala
def createUser(name: String, email: String): ConnectionIO[Unit] =
  sql"""
    insert into users (name, email)
    values ($name, $email)
  """.update.run
```

### Read

```scala
def findAllUsers: ConnectionIO[List[User]] =
  sql"select id, name, email from users".query[User].to[List]

def findUserByName(name: String): ConnectionIO[Option[User]] =
  sql"select id, name, email from users where name = $name".query[User].option
```

### Update and Delete

```scala
def updateUser(id: Long, name: String): ConnectionIO[Int] =
  sql"update users set name = $name where id = $id".update.run

def deleteUser(id: Long): ConnectionIO[Int] =
  sql"delete from users where id = $id".update.run
```

## Query Options

```scala
// Unique (expects exactly one row)
sql"select count(*) from users".query[Int].unique

// Option (expects zero or one row)
sql"select * from users where id = 1".query[User].option

// NonEmptyList (expects at least one row)
sql"select * from users where age > 18".query[User].nel

// List (accumulates all rows)
sql"select * from users".query[User].to[List]

// Stream (lazily streams results)
sql"select * from users".query[User].stream
```

## Transactions

```scala
def transfer(fromId: Long, toId: Long, amount: Double): ConnectionIO[Unit] =
  for {
    _ <- sql"update accounts set balance = balance - $amount where id = $fromId".update.run
    _ <- sql"update accounts set balance = balance + $amount where id = $toId".update.run
  } yield ()
```

## Query Composition with Fragments

Build complex queries programmatically by composing `Fragment` values:

```scala
import doobie.syntax.sql._

def buildQuery(
  activeOnly: Boolean,
  minAge: Option[Int],
  maxAge: Option[Int],
  searchTerm: Option[String]
): ConnectionIO[List[User]] = {
  val base = fr"select id, name, email from users"

  val whereClauses = List(
    activeOnly.some.filter(_ => activeOnly).map(_ => fr"active = true"),
    minAge.map(a => fr"age >= $a"),
    maxAge.map(a => fr"age <= $a"),
    searchTerm.map(s => fr"name like ${s"%$s%"})
  ).flatten

  val finalQuery = base ++ fr"where" ++ whereClauses

  finalQuery.query[User].to[List]
}
```

## Custom Data Type Mappings

```scala
import doobie._

// Custom enum mapping
case class UserRole(role: String)

implicit val roleMeta: Meta[UserRole] =
  Meta[String].timap(
    UserRole.apply,
    _.role
  )

// Complex composite type
case class Address(street: String, city: String, country: String)

implicit val addressMeta: Meta[Address] =
  Meta[String].timap(
    s => Address(s.split(",").toList.head, s.split(",").toList(1), s.split(",").toList(2)),
    a => s"${a.street},${a.city},${a.country}"
  )
```

## Error Handling

```scala
import doobie.util._

// Custom error types
sealed trait DatabaseError
case class NotFoundError() extends DatabaseError
case class MappingError(msg: String) extends DatabaseError
case class UniqueViolationError() extends DatabaseError
case class UnknownError(msg: String) extends DatabaseError

// Safe error handling with pattern matching
def findUserSafe(id: Long): IO[Either[DatabaseError, User]] =
  sql"select * from users where id = $id".query[User].option
    .transact(xa)
    .attempt
    .flatMap {
      case Right(Some(user)) => IO.pure(Right(user))
      case Right(None) => IO.pure(Left(NotFoundError()))
      case Left(e: DoobieError) =>
        IO.pure(Left(UnknownError(e.getMessage)))
    }
```

## Advanced Transactions

```scala
import doobie.util.transactor._

// Custom transaction strategies
val noStrategy = Strategy.default.copy(
  before = HC.unit,
  after = HC.unit,
  oops = HC.unit
)

val alwaysRollback = Strategy.default.copy(
  after = HC.rollback,
  oops = HC.rollback
)

val xa = Transactor.strategy.set(xa, noStrategy)
```

## Repository Pattern

```scala
case class CreateUser(name: String, email: String)

trait UserRepository[F[_]] {
  def findAll: F[List[User]]
  def findById(id: Long): F[Option[User]]
  def create(user: CreateUser): F[Unit]
  def update(id: Long, name: String): F[Unit]
  def delete(id: Long): F[Unit]
}

class UserRepositoryImpl[F[_]](xa: Transactor[F])(implicit F: MonadError[F, Throwable])
    extends UserRepository[F] {

  def findAll: F[List[User]] =
    sql"select id, name, email from users".query[User].to[List].transact(xa)

  def findById(id: Long): F[Option[User]] =
    sql"select id, name, email from users where id = $id".query[User].option.transact(xa)

  def create(user: CreateUser): F[Unit] =
    sql"""
      insert into users (name, email)
      values (${user.name}, ${user.email})
    """.update.run.transact(xa).void

  def update(id: Long, name: String): F[Unit] =
    sql"update users set name = $name where id = $id".update.run.transact(xa).void

  def delete(id: Long): F[Unit] =
    sql"delete from users where id = $id".update.run.transact(xa).void
}
```

## Performance Optimization

```scala
// Streaming for large datasets
def streamUsers(limit: Int): Stream[IO, User] =
  sql"select id, name, email from users".query[User].stream.limit(limit)

// Use .unique instead of .option for safer queries
def getUser(id: Long): ConnectionIO[User] =
  sql"select id, name, email from users where id = $id".query[User].unique
```

## Dependencies

```scala
// check for latest version
libraryDependencies ++= Seq(
  "org.tpolecat" %% "doobie-core"      % "1.0.+",
  "org.postgresql"  % "postgresql"         % "42.+",
  "org.tpolecat" %% "doobie-hikari"    % "1.0.+",
  "org.tpolecat" %% "doobie-scalatest" % "1.0.+" % Test
)
```

## Related Skills

- **scala-streaming** — when combining database access with fs2 stream processing
- **scala-async-effects** — for wrapping database operations in ZIO or cats-effect
- **scala-testing-property** — for property-based testing of database queries

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/basic-queries.md** — Complete doobie query API: ConnectionIO, query options, streaming results, connection pooling, transaction basics
- **references/advanced-patterns.md** — Fragment composition, custom Meta instances, advanced error handling, savepoints, batch operations, repository pattern deep dive
