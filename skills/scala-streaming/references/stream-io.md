# Stream I/O Reference

Complete reference for file I/O, network streams, WebSocket handling, HTTP streaming, database streaming, and stream interop patterns with fs2.

## File I/O

### File Processing

```scala
import fs2.io.file.{Files, Path}
import fs2.text

// Transform file line by line
def transformFile(in: Path, out: Path): IO[Unit] =
  Files[IO].readAll(in)
    .through(text.utf8Decode)
    .through(text.lines)
    .filter(_.nonEmpty)
    .map(_.toUpperCase)
    .intersperse("\n")
    .through(text.utf8Encode)
    .through(Files[IO].writeAll(out))
    .compile.drain

// Stream large file with custom chunk size
def streamLargeFile(path: Path): Stream[IO, Byte] =
  Files[IO].readAll(path, chunkSize = 8192)

// Read all bytes
Files[IO].readAll(Path("/data/input.bin"))

// Write bytes
bytes.through(Files[IO].writeAll(Path("/data/output.bin")))

// Append to file
bytes.through(Files[IO].writeAll(Path("/data/log.txt"), Flags.Append))
```

### Text Processing

```scala
// Decode bytes to strings
byteStream.through(text.utf8Decode)

// Split into lines
stringStream.through(text.lines)

// Encode strings to bytes
stringStream.through(text.utf8Encode)

// Combine: read file, process lines, write file
Files[IO].readAll(inputPath)
  .through(text.utf8Decode)
  .through(text.lines)
  .filter(_.nonEmpty)
  .map(_.trim)
  .intersperse("\n")
  .through(text.utf8Encode)
  .through(Files[IO].writeAll(outputPath))
  .compile.drain
```

## Network Streams

### TCP

```scala
import fs2.io.net.{Network, Socket}

// TCP client
def echoClient(host: String, port: Int): IO[Unit] =
  Network[IO].client(SocketetSocketAddress(host, port)).use { socket =>
    Stream("Hello")
      .through(text.utf8Encode)
      .through(socket.writes)
      .compile.drain >>
      socket.reads(8192)
        .through(text.utf8Decode)
        .evalTap(line => IO(println(s"Received: $line")))
        .compile.drain
  }

// TCP server
def echoServer(port: Int): IO[Unit] =
  Network[IO].server(port"1234").evalMap { client =>
    client.reads(8192)
      .through(client.writes)
      .compile.drain
  }.compile.drain
```

### UDP

```scala
import fs2.io.net.{Datagram, Network}

// UDP send
def sendDatagram(host: String, port: Int, data: Chunk[Byte]): IO[Unit] =
  Network[IO].openDatagramSocket().use { socket =>
    socket.write(Datagram(SocketSocketAddress(host, port), data))
  }

// UDP receive
def receiveDatagrams(port: Int): Stream[IO, Datagram] =
  Stream.resource(Network[IO].openDatagramSocket(port"9999"))
    .flatMap(_.reads)
```

## WebSocket

### WebSocket Handler

```scala
import fs2.concurrent.SignallingRef

def wsHandler[F[_]: Concurrent: Temporal](
  ws: WebSocket[F],
  stop: SignallingRef[F, Boolean]
): Stream[F, Unit] = {
  val receive = ws.receive
    .evalTap(msg => F.pure(println(s"Received: $msg")))

  val send = Stream
    .awakeEvery[F](1.second)
    .evalMap(_ => F.pure("ping"))
    .through(ws.send)
    .interruptWhen(stop.discrete)

  receive.concurrently(send)
}
```

### WebSocket Client (http4s)

```scala
import org.http4s.client.websocket._

def wsClient: IO[Unit] =
  WebSocketClient[IO]
    .connect(WSRequest(uri"ws://localhost:8080/ws"))
    .use { conn =>
      val send = Stream.emit(WSFrame.Text("hello")).through(conn.send)
      val recv = conn.receive.evalTap(frame => IO(println(s"Got: $frame")))
      send.concurrently(recv).compile.drain
    }
```

## HTTP Streaming

### Streaming HTTP Responses (http4s)

```scala
import org.http4s._
import org.http4s.dsl.io._

// Stream large results with chunked encoding
val routes: HttpRoutes[IO] = HttpRoutes.of[IO] {
  case GET -> Root / "items" =>
    // fs2.Stream used directly as response body — automatically chunked
    Ok(items.streamAll)

  case GET -> Root / "csv" / name =>
    // Stream CSV download
    Ok(csvStream(name))
      .map(_.putHeaders(`Content-Type`(MediaType.text.csv)))
}
```

### Streaming Request Bodies

```scala
// Stream request body
case req @ POST -> Root / "upload" =>
  req.body
    .through(Files[IO].writeAll(Path("/uploads/file.bin")))
    .compile
    .drain
    .as(Response[IO](Status.Ok))
```

## Database Streaming

### Streaming with Skunk

```scala
// Stream query results with chunk size
def findBy(brand: BrandName): Stream[IO, Item] =
  for {
    s <- Stream.resource(postgres)
    p <- Stream.resource(s.prepare(selectByBrand))
    t <- p.stream(brand, 1024)  // chunk size of 1024
  } yield t
```

### Cursor-based Pagination

```scala
case class PaginatedItems(items: List[Item], hasMore: Boolean)

def findByPage(brand: BrandName, pageSize: Int): Stream[IO, PaginatedItems] =
  for {
    s      <- Stream.resource(postgres)
    p      <- Stream.resource(s.prepare(selectByBrand))
    cursor <- Stream.resource(p.cursor(brand))
  } yield {
    val (items, hasMore) = cursor.fetch(pageSize)
    PaginatedItems(items, hasMore)
  }
```

### Streaming with Doobie

```scala
import doobie._
import doobie.implicits._

def streamUsers(xa: Transactor[IO]): Stream[IO, User] =
  sql"SELECT id, name, email FROM users"
    .query[User]
    .stream
    .transact(xa)
```

## Stream Interop

### Java Streams

```scala
import fs2.interop.flow._

val javaStream: java.util.stream.Stream[Int] = ???
Stream.fromJavaStream(javaStream)
fs2Stream.toJavaStream
```

### Reactive Streams

```scala
import fs2.interop.reactivestreams._

Stream.fromPublisher[IO](publisher)
fs2Stream.toUnicastPublisher
```

### API Pagination Pattern

```scala
def fetchPage[F[_]](page: Int): F[List[Item]]

def allPages[F[_]: Monad](fetch: Int => F[List[Item]]): Stream[F, Item] =
  Stream.unfoldLoopEval(1) { page =>
    fetch(page).map { items =>
      if (items.isEmpty) (Nil, None)
      else (items, Some(page + 1))
    }
  }.flatMap(Stream.emits)
```

## Common I/O Patterns

### Rate-limited File Processing

```scala
def processWithRateLimit[A](
  source: Stream[IO, A],
  rate: FiniteDuration,
  process: A => IO[Unit]
): Stream[IO, Unit] =
  source.evalMap(item => process(item).as(item)).metered(rate)
```

### Log File Tailing

```scala
def tailLogFile(path: Path): Stream[IO, String] =
  Files[IO].tail(path, 8192)
    .through(text.utf8Decode)
    .through(text.lines)
```

### Binary Protocol Parsing

```scala
import fs2.compression

def parseCompressed(path: Path): Stream[IO, Event] =
  Files[IO].readAll(path)
    .through(Compression[IO].gunzip())
    .through(binaryParser)      // custom pipe
    .through(eventDecoder)      // custom pipe
```
