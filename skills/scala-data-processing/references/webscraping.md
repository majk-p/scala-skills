# Advanced Data Processing - Deep Reference

## Advanced Jsoup Patterns

### Pagination and Multi-Page Scraping

```scala
import org.jsoup.Jsoup
import scala.util.control.Breaks._

def scrapeAllPages(baseUrl: String): Seq[String] = {
  val results = scala.collection.mutable.ArrayBuffer[String]()
  var page = 1

  breakable {
    while (true) {
      val url = s"$baseUrl?page=$page"
      val doc = Jsoup.connect(url).get()
      val items = doc.select(".item").asScala.map(_.text())

      if (items.isEmpty) break()

      results ++= items
      page += 1
    }
  }

  results.toSeq
}

// With delay between requests
def scrapeWithDelay(urls: Seq[String]): Seq[String] = {
  urls.zipWithIndex.flatMap { case (url, idx) =>
    Thread.sleep(1000 * idx)  // 1 second delay between requests
    val doc = Jsoup.connect(url).get()
    doc.select(".content").asScala.map(_.text())
  }
}
```

### Session Management and Headers

```scala
import org.jsoup.Jsoup
import scala.util.{Try, Success, Failure}

def scrapeWithSession(url: String): Option[String] = {
  val connection = Jsoup.connect(url)
    .userAgent("Mozilla/5.0")
    .timeout(5000)
    .referrer("https://google.com")
    .followRedirects(true)

  connection.header("Accept", "application/json")
    .header("Authorization", "Bearer token")
    .header("X-Custom-Header", "value")
    .get()
    .select(".content").asScala.headOption.map(_.text())
}

// Reuse connection
def scrapeWithConnection(url: String): String = {
  val connection = Jsoup.connect(url)
    .userAgent("Mozilla/5.0")
    .timeout(5000)
    .referrer("https://google.com")

  val doc = connection.get()

  // Can make multiple requests with same connection
  val otherDoc = connection.get("other-url")
  doc.select(".main").text()
}
```

### Robust Error Handling

```scala
import scala.util.{Try, Success, Failure}

def scrapeWebsite(url: String): Option[List[String]] = {
  val doc = Try(Jsoup.connect(url)
    .userAgent("Mozilla/5.0")
    .timeout(10000)
    .get())

  doc match {
    case Success(d) =>
      val content = d.select(".item").asScala.map(_.text()).toList
      if (content.nonEmpty) Some(content) else None

    case Failure(e) =>
      println(s"Failed to scrape $url: ${e.getMessage}")
      None
  }
}

// With retry logic
def scrapeWithRetry(url: String, maxAttempts: Int = 3): Option[String] = {
  (1 to maxAttempts).iterator.flatMap { attempt =>
    Try {
      val doc = Jsoup.connect(url)
        .userAgent("Mozilla/5.0")
        .timeout(10000)
        .get()
      doc.select(".content").asScala.headOption.map(_.text())
    }.toOption
  }.nextOption()
}
```

### Cookie and Session Handling

```scala
import org.jsoup.Jsoup
import java.util.{Cookie, Cookies}

def scrapeWithCookies(url: String): Option[String] = {
  val doc = Jsoup.connect(url)
    .userAgent("Mozilla/5.0")
    .cookie("session_id", "abc123")
    .cookie("user_token", "xyz789")
    .get()

  doc.select(".content").asScala.headOption.map(_.text())
}

// Follow redirects
def scrapeWithFollowRedirects(url: String): String = {
  val doc = Jsoup.connect(url)
    .userAgent("Mozilla/5.0")
    .timeout(10000)
    .followRedirects(true)
    .get()

  doc.select(".content").text()
}
```

## Advanced uPickle Patterns

### Nested Structures and Complex Types

```scala
case class Company(
  name: String,
  employees: List[Employee],
  departments: List[Department]
)

case class Employee(
  id: Int,
  name: String,
  position: String,
  email: Option[String],
  skills: List[String]
)

case class Department(
  name: String,
  head: String,
  teamSize: Int
)

case class Timestamp(value: Long) {
  def toIsoString: String = java.time.Instant.ofEpochMilli(value)
    .atZone(java.time.ZoneId.systemDefault())
    .toInstant.toString
}

implicit val timestampRW: ReadWriter[Timestamp] =
  readwriter[Long].bimap[Timestamp](
    _.value,
    Timestamp(_)
  )

// Complex nested parsing
val jsonStr = """{
  "name": "Acme Corp",
  "employees": [
    {"id": 1, "name": "Alice", "position": "Engineer", "email": "alice@acme.com", "skills": ["Scala", "Java"]},
    {"id": 2, "name": "Bob", "position": "Manager", "skills": ["Management"]}
  ],
  "departments": [
    {"name": "Engineering", "head": "Alice", "teamSize": 10}
  ]
}"""

val company: Company = read[Company](jsonStr)
```

### Custom ReadWriters with Validation

```scala
import upickle.default._

// Email validation
case class Email(value: String) {
  require(value.contains("@"), "Invalid email")
}

implicit val emailRW: ReadWriter[Email] =
  readwriter[String].bimap[Email](
    _.value,
    s => Email(s)
  )

// UUID validation
case class Uuid(value: String) {
  require(value.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"), "Invalid UUID")
}

implicit val uuidRW: ReadWriter[Uuid] =
  readwriter[String].bimap[Uuid](
    _.value,
    s => Uuid(s)
  )

// Date format transformation
case class Event(
  name: String,
  timestamp: Timestamp,
  id: Uuid
)

val event = Event("click", Timestamp(System.currentTimeMillis()), Uuid("123e4567-e89b-12d3-a456-426614174000"))
val json = write(event)
```

### Transformation Pipelines

```scala
import upickle.default._

// Transform pipeline
def transformData[T](json: String, transformer: T => T): T = {
  val data = read[T](json)
  val transformed = transformer(data)
  write(transformed)
  data
}

case class User(name: String, email: Option[String], age: Int)
case class UserProfile(name: String, email: String, age: Int)

def transformUser(json: String): UserProfile = {
  val user = read[User](json)

  user.copy(
    email = user.email.getOrElse(""),
    name = user.name.trim,
    age = if (user.age < 0) 0 else user.age
  )
}

val userJson = """{"name":"  alice  ","email":null,"age":-5}"""
val profile = transformUser(userJson)
```

### Handling Missing and Null Values

```scala
case class Config(
  host: String,
  port: Int = 8080,
  debug: Boolean = false,
  timeout: Option[Int] = None
)

val json1 = """{"host":"localhost"}"""
val config1 = read[Config](json1)
// Config("localhost", 8080, false, None)

val json2 = """{"host":"localhost","port":9090}"""
val config2 = read[Config](json2)
// Config("localhost", 9090, false, None)

val json3 = """{"host":"localhost","debug":true}"""
val config3 = read[Config](json3)
// Config("localhost", 8080, true, None)
```

## Performance Patterns

### Streaming Large Files

```scala
import os._

// Stream read line by line (memory efficient)
os.read.lines.stream(os.pwd / "large_file.txt")
  .filter(_.contains("ERROR"))
  .take(1000)
  .foreach { line =>
    processLine(line)
  }

// Stream write with buffering
val buffered = os.write.buffered(os.pwd / "output.txt")
try {
  for (i <- 0 until 100000) {
    buffered.write(s"Line $i\n")
  }
} finally {
  buffered.close()
}
```

### Efficient Directory Traversal

```scala
import os._

// Use os.walk with filtering (no loading all files into memory)
val scalaFiles = os.walk(os.pwd / "src")
  .filter(_.ext == "scala")
  .filter(_.baseName.startsWith("Main"))
  .toSeq

// Parallel processing with structured concurrency
os.walk(os.pwd / "data")
  .par
  .filter(_.ext == "json")
  .foreach(processJsonFile)
```

### Cache Web Requests

```scala
import java.net.{HttpURLConnection, URL}
import scala.collection.mutable

// Simple caching mechanism
object WebCache {
  private val cache = mutable.Map[String, String]()

  def get(url: String, maxAge: Long = 3600000): Option[String] = {
    cache.get(url).filter { cached =>
      System.currentTimeMillis() - cached._2 < maxAge
    }.map(_._1)
  }

  def fetch(url: String): String = {
    if (cache.contains(url)) {
      cache(url)
    } else {
      val conn = new URL(url).openConnection().asInstanceOf[HttpURLConnection]
      conn.setRequestMethod("GET")
      val response = conn.getInputStream
      val content = scala.io.Source.fromInputStream(response).mkString
      cache(url) = content
      content
    }
  }
}

// Usage
WebCache.get("https://example.com/api/data").foreach { cached =>
  println("Using cached data")
} match {
  case None =>
    val freshData = WebCache.fetch("https://example.com/api/data")
    process(freshData)
}
```

### Batch Processing Optimization

```scala
case class FileProcessingResult(
  processed: Int,
  skipped: Int,
  errors: Seq[String]
)

def processFilesWithCache(inputDir: os.Path, outputDir: os.Path): FileProcessingResult = {
  var processed = 0
  var skipped = 0
  var errors = List[String]()

  os.list(inputDir).foreach { file =>
    val cacheKey = file.last

    if (os.exists(outputDir / cacheKey)) {
      skipped += 1
    } else {
      try {
        val content = os.read(file)
        val processedContent = transformContent(content)
        os.write.over(outputDir / cacheKey, processedContent)
        processed += 1
      } catch {
        case ex: Exception =>
          errors = ex.getMessage :: errors
      }
    }
  }

  FileProcessingResult(processed, skipped, errors)
}
```

## External Resources

- uPickle: https://com-lihaoyi.github.io/upickle/
- Jsoup: https://jsoup.org/
- Hands-on Scala: https://www.handsonscala.com/