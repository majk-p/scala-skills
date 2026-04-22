# Doobie Advanced Patterns Reference

Complete reference for advanced doobie patterns including fragment composition, custom mappings, and performance.

## Fragment Composition

### Building Dynamic Queries

```scala
import doobie.syntax.string._

// Fragments compose with ++
val select = fr"select id, name, email"
val from = fr"from users"
val where = fr"where active = true"

val query = (select ++ from ++ where).query[User]

// Conditional where clauses
def search(activeOnly: Boolean, minAge: Option[Int]): ConnectionIO[List[User]] = {
  val base = fr"select id, name, email from users where 1=1"
  val active = if (activeOnly) Some(fr"and active = true") else None
  val age = minAge.map(a => fr"and age >= $a")

  val clauses = base :: active.toList ::: age.toList
  clauses.foldLeft(fr"")(_ ++ _).query[User].to[List]
}
```

### Fragments with IN Clauses

```scala
def findByIds(ids: List[Long]): ConnectionIO[List[User]] = {
  val f = fr"select id, name, email from users where" ++ Fragments.in(fr"id", ids)
  f.query[User].to[List]
}
```

## Custom Meta Instances

### Enum Mapping

```scala
sealed trait Status
case object Active extends Status
case object Inactive extends Status

implicit val statusMeta: Meta[Status] =
  Meta[String].timap(
    {
      case "active" => Active
      case "inactive" => Inactive
    },
    {
      case Active => "active"
      case Inactive => "inactive"
    }
  )
```

### JSON Column Mapping

```scala
import io.circe.{Decoder, Encoder}
import doobie.postgres.circe.jsonb.implicits._

// Automatic JSON column support
case class Metadata(data: Map[String, String])

implicit val metaEncoder: Encoder[Metadata] = Encoder.encodeMap[String, String].contramap(_.data)
implicit val metaDecoder: Decoder[Metadata] = Decoder.decodeMap[String, String].map(Metadata.apply)
```

## Advanced Error Handling

### SqlState Classification

```scala
import doobie.postgres.sqlstate

def insertSafe(user: User): IO[Either[DatabaseError, Unit]] =
  sql"insert into users (name, email) values (${user.name}, ${user.email})"
    .update.run
    .transact(xa)
    .attemptSqlState
    .map {
      case Right(_) => Right(())
      case Left(sqlstate.CLASS23.UNIQUE_VIOLATION) =>
        Left(UniqueViolationError())
      case Left(state) =>
        Left(UnknownError(state.value))
    }
```

### Savepoints for Nested Transactions

```scala
def withSavepoint[A](code: ConnectionIO[A]): ConnectionIO[A] =
  HC.prepareStatement("SAVEPOINT sp").flatMap { st =>
    HC.executeUpdate(st, ()).flatMap { _ =>
      code.handleErrorWith { error =>
        HC.executeUpdate("ROLLBACK TO SAVEPOINT sp", ()).flatMap { _ =>
          HC.raiseError(error)
        }
      }
    }
  }
```

## Batch Operations

```scala
import doobie.util.Update

def batchInsert(users: List[CreateUser]): ConnectionIO[Int] = {
  val sql = "insert into users (name, email) values (?, ?)"
  Update[CreateUser](sql).updateMany(users)
}
```

## Repository Pattern with Tagless Final

```scala
trait UserRepository[F[_]] {
  def findAll: F[List[User]]
  def findById(id: Long): F[Option[User]]
  def create(user: CreateUser): F[Unit]
  def update(id: Long, name: String): F[Unit]
  def delete(id: Long): F[Unit]
}

object UserRepository {
  def impl[F[_]: MonadError[*[_], Throwable]](xa: Transactor[F]): UserRepository[F] =
    new UserRepository[F] {
      def findAll: F[List[User]] =
        sql"select id, name, email from users".query[User].to[List].transact(xa)

      def findById(id: Long): F[Option[User]] =
        sql"select id, name, email from users where id = $id".query[User].option.transact(xa)

      def create(user: CreateUser): F[Unit] =
        sql"insert into users (name, email) values (${user.name}, ${user.email})".update.run.transact(xa).void

      def update(id: Long, name: String): F[Unit] =
        sql"update users set name = $name where id = $id".update.run.transact(xa).void

      def delete(id: Long): F[Unit] =
        sql"delete from users where id = $id".update.run.transact(xa).void
    }
}
```

## Streaming Results

```scala
import fs2.Stream

// Stream large datasets with backpressure
def streamAllUsers: Stream[IO, User] =
  sql"select id, name, email from users".query[User].stream.transact(xa)

// Process chunks
def processUsers: IO[Unit] =
  streamAllUsers
    .chunkN(100)
    .evalMap(chunk => processChunk(chunk.toList))
    .compile
    .drain
```
