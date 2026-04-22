# Advanced Subprocess Management - Complete Reference

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

// Working directory
os.proc("command").call(cwd = os.pwd / "subdir")

// Environment variables
os.proc("command").call(
  env = Map(
    "VAR1" -> "value1",
    "VAR2" -> "value2"
  )
)
```

### Process Monitoring

```scala
// Check if process is alive
val process = os.proc("long-task").spawn()
if (process.isAlive()) {
  println("Process is still running")
}

// Wait for completion
val result = process.waitFor()
println(s"Exit code: ${result.exitCode}")

// Get process output
val output = process.stdout()
val errors = process.stderr()
```

### Process Output Handling

#### ProcessOutput Types

```scala
// Redirect to path
stdout = os.pwd / "output.txt"

// Read lines
stdout = os.ProcessOutput.Readlines(line => println(line))

// Raw bytes
stdout = os.ProcessOutput { (bytes, len) =>
  // Process bytes
}

// Pipe to stdout
stderr = os.ProcessOutput.PipeToStdout

// Redirect to another ProcessOutput
stdout = os.ProcessOutput.Redirect(os.ProcessOutput.Readlines(_ => ()))
```

#### Line Processing

```scala
// Process each line
os.proc("command").call(
  stdout = os.ProcessOutput.Readlines { line =>
    println(s"Line: $line")
  }
)

// Filter lines
os.proc("command").call(
  stdout = os.ProcessOutput.Readlines { line =>
    if (line.contains("error")) println(line)
  }
)
```

### Interactive Patterns

#### Bidirectional Communication

```scala
val process = os.proc("grep", "pattern").spawn()

// Write input
process.stdin.write("line 1\n")
process.stdin.write("pattern\n")
process.stdin.write("line 3\n")
process.stdin.flush()
process.stdin.close()

// Read output
val result = process.waitFor()
println(result.out.text())
```

#### REPL Interaction

```scala
val python = os.proc("python", "-i").spawn()

// Send commands
List("x = 10", "y = 20", "print(x + y)").foreach { cmd =>
  python.stdin.write(s"$cmd\n")
  python.stdin.flush()
}

python.stdin.close()
python.waitFor()
```

### Error Handling

#### Exit Code Patterns

```scala
val result = os.proc("command").call()
result.exitCode match {
  case 0 => println("Success")
  case 1 => println("General error")
  case 2 => println("Misuse of shell")
  case 127 => println("Command not found")
  case code => println(s"Unknown error: $code")
}
```

#### Try-Catch Patterns

```scala
try {
  os.proc("command").call(timeout = 30000)
} catch {
  case _: java.util.concurrent.TimeoutException =>
    println("Command timed out")
  case ex: java.io.IOException =>
    println(s"IO error: ${ex.getMessage}")
}
```

#### Validation

```scala
def validateResult(result: os.ProcessOutput): Either[String, String] = {
  if (result.exitCode == 0) {
    Right(result.out.text().trim)
  } else {
    Left(s"Command failed: ${result.err.text()}")
  }
}
```

## Pattern Reference

### Streaming Transformation

```scala
def streamTransform(input: os.Path, output: os.Path): Unit = {
  os.proc("cat", input).call(
    stdout = os.ProcessOutput.Readlines { line =>
      os.write.append(output, line.toUpperCase + "\n")
    }
  )
}
```

### Progress Reporting

```scala
def processWithProgress(cmd: os.Shellable*, total: Int): Unit = {
  var processed = 0
  os.proc(cmd: _*).call(
    stdout = os.ProcessOutput.Readlines { _ =>
      processed += 1
      if (processed % 100 == 0) {
        println(s"Progress: $processed/$total")
      }
    }
  )
}
```

### Background Process Monitoring

```scala
def monitorBackgroundProcess(process: os.SubProcess): Unit = {
  new Thread(() => {
    while (process.isAlive()) {
      Thread.sleep(1000)
    }
    val result = process.waitFor()
    if (result.exitCode != 0) {
      println(s"Process failed: ${result.err.text()}")
    }
  }).start()
}
```

### Parallel Process Execution

```scala
import scala.concurrent._
import ExecutionContext.Implicits.global

def runParallel(commands: Seq[Seq[String]]): Seq[Either[String, String]] = {
  val futures = commands.map { cmd =>
    Future {
      try {
        val result = os.proc(cmd: _*).call()
        if (result.exitCode == 0) Right(result.out.text())
        else Left(s"Failed: ${result.err.text()}")
      } catch {
        case ex: Exception => Left(s"Error: ${ex.getMessage}")
      }
    }
  }
  Await.result(Future.sequence(futures), 1.hour)
}
```

### Retry Pattern

```scala
def retryWithBackoff[T](
  fn: => T,
  maxRetries: Int = 3,
  initialDelay: Long = 1000
): Either[Exception, T] = {
  (1 to maxRetries).iterator.flatMap { attempt =>
    try {
      Some(Right(fn))
    } catch {
      case ex: Exception =>
        if (attempt == maxRetries) None
        else {
          Thread.sleep(initialDelay * attempt)
          None
        }
    }
  }.nextOption().getOrElse(Left(new Exception("All retries failed")))
}
```

### Timeout Handling

```scala
import scala.concurrent.duration._

def runWithTimeout[T](
  cmd: os.Shellable*,
  timeout: FiniteDuration = 30.seconds
): Either[String, String] = {
  try {
    val result = os.proc(cmd: _*).call(timeout = timeout.toMillis)
    if (result.exitCode == 0) Right(result.out.text().trim)
    else Left(s"Command failed with code ${result.exitCode}")
  } catch {
    case _: java.util.concurrent.TimeoutException =>
      Left(s"Command timed out after ${timeout}")
    case ex: Exception =>
      Left(s"Error: ${ex.getMessage}")
  }
}
```

### Output Filtering

```scala
def filterOutput(cmd: os.Shellable*, filter: String => Boolean): Seq[String] = {
  var results = List.empty[String]
  os.proc(cmd: _*).call(
    stdout = os.ProcessOutput.Readlines { line =>
      if (filter(line)) results = line :: results
    }
  )
  results.reverse
}

// Usage
val errors = filterOutput("make", "build", _.contains("error"))
val warnings = filterOutput("make", "build", _.contains("warning"))
```

### Log Aggregation

```scala
def aggregateLog(cmd: os.Shellable*, outputFile: os.Path): Unit = {
  os.proc(cmd: _*).call(
    stdout = os.ProcessOutput.Readlines { line =>
      val timestamp = new java.util.Date()
      os.write.append(outputFile, s"[$timestamp] $line\n")
    },
    stderr = os.ProcessOutput.Readlines { line =>
      val timestamp = new java.util.Date()
      os.write.append(outputFile, s"[$timestamp] ERROR: $line\n")
    }
  )
}
```

## External Resources

- os-lib: https://github.com/com-lihaoyi/os-lib
- Hands-on Scala: https://www.handsonscala.com/
