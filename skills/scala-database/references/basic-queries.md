# Doobie Basic Queries Reference

Complete API reference for basic doobie query operations.

## Query Construction

### String Interpolation

```scala
// Basic query
sql"select * from users".query[User]

// Parameterized query
sql"select * from users where id = $id".query[User]

// Multi-line query
sql"""
  select id, name, email
  from users
  where active = true
  order by name
""".query[User]
```

### Query Result Types

```scala
// .unique — expects exactly 1 row, throws if 0 or 2+
val count: ConnectionIO[Int] = sql"select count(*) from users".query[Int].unique

// .option — expects 0 or 1 row
val maybeUser: ConnectionIO[Option[User]] = sql"select * from users where id = $id".query[User].option

// .nel — expects at least 1 row, returns NonEmptyList
val users: ConnectionIO[NonEmptyList[User]] = sql"select * from users where active = true".query[User].nel

// .to[List] — returns all rows as List
val allUsers: ConnectionIO[List[User]] = sql"select * from users".query[User].to[List]

// .stream — lazily streams results via fs2
val userStream: Stream[ConnectionIO, User] = sql"select * from users".query[User].stream
```

## Update Operations

```scala
// Execute update
val rowsAffected: ConnectionIO[Int] = sql"update users set name = $name where id = $id".update.run

// Update with generated key
val newId: ConnectionIO[Long] = sql"insert into users (name) values ($name)".update.withUniqueGeneratedKeys[Long]("id")
```

## Connection Management

### DriverManager Transactor

```scala
val xa = Transactor.fromDriverManager[IO](
  driver = "org.postgresql.Driver",
  url = "jdbc:postgresql:mydb",
  user = "postgres",
  password = "password"
)
```

### HikariCP Transactor

```scala
import doobie.hikari._

val xa: Resource[IO, HikariTransactor[IO]] =
  for {
    hikari <- HikariTransactor.newHikariTransactor[IO](
      driverClassName = "org.postgresql.Driver",
      url = "jdbc:postgresql:mydb",
      user = "postgres",
      pass = "password"
    )
  } yield hikari
```

## Transaction Basics

```scala
// Automatic transaction — for-comprehension runs in single transaction
val transfer: ConnectionIO[Unit] = for {
  _ <- sql"update accounts set balance = balance - $amount where id = $from".update.run
  _ <- sql"update accounts set balance = balance + $amount where id = $to".update.run
} yield ()

// Execute
transfer.transact(xa)
```

## Row Mapping

```scala
// Automatic mapping for case classes (column order must match)
case class User(id: Long, name: String, email: String)
sql"select id, name, email from users".query[User]

// Tuple mapping
sql"select name, email from users".query[(String, String)]

// Single column
sql"select count(*) from users".query[Int]

// Option types for nullable columns
case class User(id: Long, name: String, email: Option[String])
sql"select id, name, email from users".query[User]
```
