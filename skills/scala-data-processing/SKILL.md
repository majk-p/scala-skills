---
name: scala-data-processing
description: Use this skill for data processing tasks in Scala including file I/O with os-lib, subprocess management, and web scraping with Jsoup. Covers reading/writing files, directory operations, streaming subprocess output, interactive processes, CSS selectors, pagination, JSON processing with uPickle, and batch operations. Trigger when the user mentions data processing, file I/O, subprocess, web scraping, HTML parsing, JSON transformation, or batch data operations.
---

# Data Processing in Scala

Practical data processing patterns in Scala using **os-lib** for file I/O and subprocess management, **Jsoup** for web scraping, and **uPickle** for JSON processing.

## Quick Start

### File Operations (os-lib)

```scala
import os._

// Read and write files
val content = os.read(os.pwd / "data.txt")
os.write.over(os.pwd / "output.txt", content)

// Directory operations
val files = os.list(os.pwd / "data")

// Subprocess execution
val result = os.proc("ls", "-la").call()
println(result.out.text())
```

### Web Scraping (Jsoup)

```scala
import org.jsoup.Jsoup
import scala.jdk.CollectionConverters._

val doc = Jsoup.connect("https://example.com").get()
val title = doc.select("h1").text()
val links = doc.select("a").asScala.map(_.attr("href"))
```

### JSON Processing (uPickle)

```scala
import upickle.default._

case class User(name: String, age: Int)
val user = User("alice", 30)
val json = write(user)
val parsed = read[User](json)
```

## File I/O with os-lib

### Basic Operations

```scala
import os._

// Read/write
val text = os.read(os.pwd / "input.txt")
os.write.over(os.pwd / "output.txt", text)

// Append
os.write.append(os.pwd / "log.txt", "new line\n")

// Directory listing
val files = os.list(os.pwd / "data")
val scalaFiles = os.walk(os.pwd / "src").filter(_.last.endsWith(".scala"))

// Copy/move
os.copy(os.pwd / "a.txt", os.pwd / "b.txt")
os.move(os.pwd / "old.txt", os.pwd / "new.txt")
```

### Subprocess Execution

```scala
import os._

// Simple command
val result = os.proc("ls", "-la").call()
println(result.out.text())

// With working directory and environment
os.proc("npm", "install").call(cwd = os.pwd / "frontend")
os.proc("command").call(env = Map("JAVA_HOME" -> "/usr/lib/jvm/java-11"))

// Shell pipelines
val count = os.proc("bash", "-c", "cat input.txt | grep error | wc -l").call()
```

### Streaming Output

```scala
os.proc("tail", "-f", "log.txt").call(
  stdout = os.ProcessOutput.Readlines(println)
)

os.proc("script").call(
  stdout = os.ProcessOutput.Readlines(line => println(s"OUT: $line")),
  stderr = os.ProcessOutput.Readlines(line => println(s"ERR: $line"))
)

// Redirect to file
os.proc("make", "build").call(stdout = os.pwd / "build.log")
```

### Interactive Processes

```scala
val python = os.proc("python", "-i").spawn()
List("x = 10", "y = 20", "print(x + y)").foreach { cmd =>
  python.stdin.write(s"$cmd\n")
  python.stdin.flush()
}
python.stdin.close()
python.waitFor()

// Bidirectional communication
val grep = os.proc("grep", "error").spawn()
List("line 1\n", "error here\n", "line 3\n").foreach(grep.stdin.write)
grep.stdin.flush()
grep.stdin.close()
println(grep.waitFor().out.text())
```

### Process Monitoring & Error Handling

```scala
// Timeout
try {
  os.proc("long-command").call(timeout = 30000)
} catch {
  case _: java.util.concurrent.TimeoutException => println("Timed out")
}

// Exit code checking
val result = os.proc("make", "build").call()
if (result.exitCode == 0) println("Success")
else println(s"Failed: ${result.err.text()}")

// Safe wrapper
def runCommand(cmd: os.Shellable*): Either[String, String] =
  try {
    val r = os.proc(cmd: _*).call(timeout = 30000)
    if (r.exitCode == 0) Right(r.out.text().trim)
    else Left(s"Failed with code ${r.exitCode}: ${r.err.text()}")
  } catch {
    case ex: java.io.IOException => Left(s"IO error: ${ex.getMessage}")
    case _: java.util.concurrent.TimeoutException => Left("Timed out")
  }
```

## Web Scraping with Jsoup

### Fetching and Parsing

```scala
import org.jsoup.Jsoup

val doc = Jsoup.connect("https://example.com")
  .timeout(5000)
  .userAgent("Mozilla/5.0")
  .get()

// From string
val doc = Jsoup.parse("<div>Hello & world</div>")
```

### CSS Selectors

```scala
val paragraphs = doc.select("p")            // By tag
val links = doc.select(".link")             // By class
val header = doc.select("#header")          // By ID
val inputs = doc.select("input[type='text']")  // By attribute
val nested = doc.select("div.container p.intro")  // Descendant
val direct = doc.select("div.container > p.intro")  // Direct child
```

### Extracting Data

```scala
val title = doc.select("h1").text()
val hrefs = doc.select("a").asScala.map(_.attr("href"))
val dataIds = doc.select("[data-id]").asScala.map(_.attr("data-id"))
val items = doc.select("li.item").asScala.map(_.text())
```

### Pagination

```scala
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
```

### Robust Scraping

```scala
import scala.util.{Try, Success, Failure}

def scrapeWebsite(url: String): Option[List[String]] =
  Try(Jsoup.connect(url).userAgent("Mozilla/5.0").timeout(10000).get()) match {
    case Success(d) =>
      val content = d.select(".item").asScala.map(_.text()).toList
      if (content.nonEmpty) Some(content) else None
    case Failure(e) =>
      println(s"Failed to scrape $url: ${e.getMessage}")
      None
  }

def scrapeWithDelay(urls: Seq[String]): Seq[String] =
  urls.zipWithIndex.flatMap { case (url, idx) =>
    Thread.sleep(1000 * idx)
    val doc = Jsoup.connect(url).get()
    doc.select(".content").asScala.map(_.text())
  }
```

## JSON Processing with uPickle

### Nested Structures

```scala
import upickle.default._

case class Employee(id: Int, name: String, skills: List[String])
case class Company(name: String, employees: List[Employee])

val json = """{"name":"Acme","employees":[{"id":1,"name":"Alice","skills":["Scala"]}]}"""
val company = read[Company](json)
```

### Custom Serialization

```scala
implicit val timestampRW: ReadWriter[Timestamp] =
  readwriter[Long].bimap[Timestamp](_.value, Timestamp(_))

case class Email(value: String) { require(value.contains("@"), "Invalid email") }
implicit val emailRW: ReadWriter[Email] =
  readwriter[String].bimap[Email](_.value, Email(_))
```

## Batch Operations

### Parallel Processing

```scala
import scala.concurrent._
import ExecutionContext.Implicits.global

def processParallel(files: Seq[os.Path]): Unit = {
  val futures = files.map(file => Future(processFile(file)))
  Await.result(Future.sequence(futures), 1.hour)
}
```

### Error Handling & Retries

```scala
def retry[T](fn: => T, maxAttempts: Int = 3, delayMs: Long = 1000): Either[Exception, T] =
  (1 to maxAttempts).iterator.flatMap { attempt =>
    try Some(Right(fn))
    catch {
      case ex: Exception =>
        if (attempt == maxAttempts) Left(ex) else { Thread.sleep(delayMs * attempt); None }
    }
  }.nextOption().getOrElse(Left(new Exception("All retries failed")))
```

## Dependencies

```scala
libraryDependencies += "com.lihaoyi" %% "os-lib" % "0.11.+"
libraryDependencies += "com.lihaoyi" %% "upickle" % "3.1.+"
libraryDependencies += "org.jsoup" % "jsoup" % "1.21.+"
```

## Related Skills

- **scala-streaming** — for fs2-based stream processing of large datasets
- **scala-http-clients** — for HTTP client operations complementary to web scraping
- **scala-build-tools** — for project setup and dependency management

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/os-lib.md** — Complete os-lib reference: file operations, path manipulation, subprocess management, streaming patterns
- **references/subprocess.md** — Advanced subprocess patterns: interactive processes, process monitoring, pipelines, error handling strategies, retry patterns
- **references/webscraping.md** — Advanced web scraping patterns: CSS selectors, pagination, session management, rate limiting, JSON processing with uPickle, batch operations
