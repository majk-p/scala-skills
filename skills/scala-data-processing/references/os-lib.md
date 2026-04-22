# Data Processing Scripts - Complete Reference

## os-lib API Reference

### Path Types

```scala
// Absolute path
val absolute: os.Path = os.home / "project" / "file.txt"

// Relative path
val relative: os.RelPath = os.rel / "data" / "file.txt"

// Sub-path
val subPath: os.SubPath = os.sub / "nested" / "file.txt"
```

### Path Operations

#### Construction

```scala
// Root paths
val home: os.Path = os.home  // User home directory
val pwd: os.Path = os.pwd  // Current working directory

// Build paths
val path1 = os.pwd / "data" / "file.txt"
val path2 = os.pwd / os.rel / "nested" / "file.txt"

// Parent directory
val parent = (os.pwd / "subdir") / os.up

// Path properties
val segments: Seq[String] = path.segments
val ext: String = path.ext  // File extension
val baseName: String = path.baseName  // File without extension
```

#### File Tests

```scala
os.exists(path)  // File or directory exists
os.isFile(path)  // Is a file
os.isDir(path)  // Is a directory
os.isLink(path)  // Is a symbolic link
```

### Directory Operations

#### Listing

```scala
// List immediate files
val files: Seq[os.Path] = os.list(dir)

// Walk directory recursively (stream)
val allFiles: Iterator[os.Path] = os.walk(dir)

// Filter while walking
val scalaFiles: Seq[os.Path] =
  os.walk(dir).filter(_.ext == "scala").toSeq
```

#### Creation

```scala
// Create directory (fail if exists)
os.makeDir(dir)

// Create directory and all parents
os.makeDir.all(dir / "nested" / "path")

// Create temporary directory
val tempDir = os.temp.dir()  // In system temp directory
val namedTemp = os.temp.dir(prefix="cache_")  // With prefix

// Create temporary file
val tempFile = os.temp.file()
val tempFileWithSuffix = os.temp.file(suffix=".json")
```

#### Removal

```scala
// Remove file
os.remove(file)

// Remove directory (must be empty)
os.remove(emptyDir)

// Remove directory and all contents
os.remove.all(dir)
```

### File Operations

#### Reading

```scala
// Read entire file as string
val content: String = os.read(file)

// Read as bytes
val bytes: Array[Byte] = os.read.bytes(file)

// Read lines
val lines: Seq[String] = os.read.lines(file)

// Stream read lines
os.read.lines.stream(file).foreach { line =>
  println(line)
}
```

#### Writing

```scala
// Write file (fail if exists)
os.write(file, "content")

// Write or overwrite
os.write.over(file, "content")

// Append to file
os.write.append(file, "more content")

// Write bytes
os.write.bytes(file, byteArr)
```

#### Copy and Move

```scala
// Copy file (fail if dest exists)
os.copy(src, dest)

// Copy or overwrite
os.copy.over(src, dest)

// Move file
os.move(src, dest)
```

### File Metadata

```scala
// Get file stats
val stat: os.StatInfo = os.stat(file)
val size: Long = stat.size
val mtime: os.millis = stat.mtime  // Last modified time

// Check file size
if (os.stat(file).size > 1024 * 1024) {
  println("Large file")
}
```

### Glob Patterns

```scala
// Match files by pattern
val jsonFiles = os.walk(dir).filter(_.glob("*.json"))

// Match in specific directory
val configFiles = os.list(os.home / ".config")
  .filter(_.glob("*.conf"))
```

## Subprocess API Reference

### Command Execution

#### Simple Execution

```scala
import os._

// Run command synchronously
val result = os.proc("ls", "-la").call()

// Get results
val stdout: String = result.out.text()
val stderr: String = result.err.text()
val exitCode: Int = result.exitCode

// Check success
if (result.exitCode == 0) {
  println("Success")
} else {
  println(s"Failed: ${result.err.text()}")
}
```

#### Command Building

```scala
// Simple command
os.proc("echo", "hello")

// Multiple arguments
os.proc("git", "commit", "-m", "Fixed bug")

// Using shell
os.proc("bash", "-c", "ls | grep .txt")

// Using working directory
os.proc("npm", "install").call(cwd = os.pwd / "frontend")

// With environment variables
os.proc("java", "-jar", "app.jar").call(
  env = Map("JAVA_HOME" -> "/usr/lib/jvm/java-11", "APP_ENV" -> "production")
)
```

#### Streaming Output

```scala
// Stream stdout
os.proc("tail", "-f", "log.txt").call(
  stdout = os.ProcessOutput { (bytes, len) =>
    val line = new String(bytes.take(len))
    println(line)
  }
)

// Stream both stdout and stderr
os.proc("command").call(
  stdout = os.ProcessOutput.Readlines(line => println(s"OUT: $line")),
  stderr = os.ProcessOutput.Readlines(line => println(s"ERR: $line"))
)

// Redirect to file
os.proc("make", "build").call(
  stdout = os.pwd / "build.log"
)
```

#### Interactive Processes

```scala
// Spawn process
val process = os.proc("python").spawn()

// Write to stdin
process.stdin.write("print('hello')\n")
process.stdin.flush()

// Close stdin
process.stdin.close()

// Wait for completion
val result = process.waitFor()
```

#### Pipes and Chains

```scala
// Using shell for pipes
val result = os.proc("bash", "-c", "cat input.txt | grep error | wc -l").call()

// Multiple commands
val chain = os.proc("bash", "-c",
  "cd /path && make && ./run_tests"
)
```

### Subprocess Options

```scala
// Timeout (in milliseconds)
os.proc("long-command").call(timeout = 30000)  // 30 seconds

// Merge stdout and stderr
os.proc("command").call(
  stderr = os.ProcessOutput.PipeToStdout
)

// Suppress output
os.proc("quiet-command").call(
  stdout = os.ProcessOutput.Redirect(os.ProcessOutput.Readlines(_ => ())),
  stderr = os.ProcessOutput.Redirect(os.ProcessOutput.Readlines(_ => ()))
)
```

## Jsoup API Reference

### Document Loading

```scala
import org.jsoup.Jsoup

// Load from URL
val doc = Jsoup.connect("https://example.com").get()

// With timeout
val doc = Jsoup.connect(url).timeout(5000).get()

// With user agent
val doc = Jsoup.connect(url)
  .userAgent("Mozilla/5.0")
  .get()

// Load from file
val doc = Jsoup.parse(os.read(file))

// Load from string
val doc = Jsoup.parse(htmlString)
```

### Element Selection

#### Basic Selectors

```scala
// By tag
val paragraphs = doc.select("p")
val headers = doc.select("h1")

// By class
val links = doc.select(".link")
val items = doc.select(".item.featured")

// By ID
val header = doc.select("#main-header")

// By attribute
val inputs = doc.select("input[type='text']")
val links = doc.select("[href]")

// Multiple selectors
val all = doc.select("p, div.content, h2")
```

#### Combinators

```scala
// Descendant (space)
val nested = doc.select("div.container p")

// Direct child (>)
val direct = doc.select("ul.menu > li")

// Adjacent sibling (+)
val sibling = doc.select("h1 + h2")

// General sibling (~)
val allSiblings = doc.select("h1 ~ h2")

// Pseudo-classes
val first = doc.select("li:first-child")
val even = doc.select("tr:even")
val contains = doc.select("p:contains(hello)")
```

### Data Extraction

#### Text and Attributes

```scala
// Extract text
val title = doc.select("h1").text()
val body = doc.select("body").text()

// Extract attributes
val hrefs = doc.select("a")
  .asScala
  .map(_.attr("href"))

val srcs = doc.select("img")
  .asScala
  .map(_.attr("src"))

// Data attributes
val dataIds = doc.select("[data-id]")
  .asScala
  .map(_.attr("data-id"))

// Multiple attributes
val links = doc.select("a").asScala.map { a =>
  (a.attr("href"), a.text())
}
```

#### HTML Content

```scala
// Get inner HTML
val inner = element.html()

// Get outer HTML (including element)
val outer = element.outerHtml()

// Get element tag
val tag = element.tagName()
```

### Navigation

```scala
// Get parent
val parent = element.parent()

// Get children
val children = element.children()

// Get first/last
val first = element.firstElementSibling()
val last = element.lastElementSibling()

// Get next/previous
val next = element.nextElementSibling()
val prev = element.previousElementSibling()
```

## uPickle API Reference

### Basic Serialization

```scala
import upickle.default._

// Write JSON
val json: String = write(value)

// Read JSON
val value: T = read[T](json)

// Write to file
os.write.over(file, write(data))

// Read from file
val data: T = read[T](os.read(file))
```

### Case Classes

```scala
case class Person(name: String, age: Int)
case class Item(id: Int, name: String, price: Double)

// Serialize
val person = Person("alice", 30)
val json = write(person)

// Deserialize
val parsed = read[Person](json)

// List of case classes
val items = List(Item(1, "A", 10.0), Item(2, "B", 20.0))
val jsonList = write(items)
val parsedList = read[List[Item]](jsonList)
```

### Advanced Features

#### Custom Keys

```scala
case class Data(
  @upickle.key("user_name") name: String,
  @upickle.key("user_id") id: Int
)

val json = write(Data("alice", 123))
// {"user_name":"alice","user_id":123}
```

#### Default Values

```scala
case class Config(
  host: String,
  port: Int = 8080,
  debug: Boolean = false
)

val json = """{"host":"localhost"}"""
val config = read[Config](json)
// Config("localhost", 8080, false)
```

#### Option Fields

```scala
case class User(
  name: String,
  email: Option[String],
  age: Int
)

val json1 = write(User("alice", None, 30))
// {"name":"alice","email":null,"age":30}

val json2 = write(User("bob", Some("bob@example.com"), 25))
// {"name":"bob","email":"bob@example.com","age":25}
```

### Custom ReadWriters

```scala
import upickle.default._

// Simple transformation
implicit val dateRW: ReadWriter[java.time.LocalDate] =
  readwriter[String].bimap[java.time.LocalDate](
    _.toString,  // Write
    java.time.LocalDate.parse  // Read
  )

// With validation
case class Email(value: String) {
  require(value.contains("@"), "Invalid email")
}

implicit val emailRW: ReadWriter[Email] =
  readwriter[String].bimap[Email](
    _.value,
    s => Email(s)
  )

// Use in case class
case class User(name: String, email: Email)

val user = User("alice", Email("alice@example.com"))
val json = write(user)
val parsed = read[User](json)
```

## Pattern Reference

### File Processing Pipeline

```scala
def processFiles(inputDir: os.Path, outputDir: os.Path): Unit = {
  os.walk(inputDir)
    .filter(_.ext == "txt")
    .foreach { file =>
      val content = os.read(file)
      val processed = content.toUpperCase
      os.write.over(outputDir / file.last, processed)
    }
}
```

### Parallel Processing

```scala
import scala.concurrent._
import ExecutionContext.Implicits.global

def processParallel(files: Seq[os.Path]): Unit = {
  val futures = files.map { file =>
    Future {
      processFile(file)
    }
  }

  Await.result(Future.sequence(futures), 1.hour)
}
```

### Retry Pattern

```scala
def retry[T](fn: => T, maxAttempts: Int = 3): Either[Exception, T] = {
  (1 to maxAttempts).iterator.flatMap { attempt =>
    try {
      Some(Right(fn))
    } catch {
      case ex: Exception =>
        if (attempt == maxAttempts) None
        else {
          Thread.sleep(1000 * attempt)
          None
        }
    }
  }.nextOption().getOrElse(Left(new Exception("All retries failed")))
}
```

### Batch Processing with Progress

```scala
def processWithProgress[T](
  items: Seq[T],
  process: T => Unit,
  reportInterval: Int = 100
): Unit = {
  items.zipWithIndex.foreach { case (item, idx) =>
    process(item)
    if ((idx + 1) % reportInterval == 0) {
      println(s"Processed ${idx + 1}/${items.length}")
    }
  }
}
```

## External Resources

- os-lib: https://github.com/com-lihaoyi/os-lib
- uPickle: https://com-lihaoyi.github.io/upickle/
- Jsoup: https://jsoup.org/
- Hands-on Scala: https://www.handsonscala.com/
