# Build Tools - Complete Reference

This reference provides comprehensive documentation for sbt, scala-cli, and essential SBT plugins.

## Table of Contents

1. [SBT Complete Reference](#sbt-complete-reference)
2. [Scala-CLI Complete Reference](#scala-cli-complete-reference)
3. [SBT Plugins Reference](#sbt-plugins-reference)
   - [sbt-assembly](#sbt-assembly)
   - [sbt-native-packager](#sbt-native-packager)
   - [sbt-scoverage](#sbt-scoverage)
   - [sbt-git](#sbt-git)
   - [sbt-scalafmt](#sbt-scalafmt)
   - [sbt-buildinfo](#sbt-buildinfo)
   - [sbt-jmh](#sbt-jmh)
   - [sbt-web](#sbt-web)
   - [sbt-protobuf](#sbt-protobuf)
   - [sbt-pgp](#sbt-pgp)
   - [sbt-dynver](#sbt-dynver)
4. [Cross-Platform Reference](#cross-platform-reference)
5. [Migration Patterns](#migration-patterns)
6. [CI/CD Integration](#cicd-integration)
7. [Performance Optimization](#performance-optimization)

---

## SBT Complete Reference

### Project Structure

Standard sbt project layout:

```
my-project/
├── build.sbt                  # Main build definition (.sbt format)
├── project/
│   ├── build.properties       # sbt.version setting
│   ├── plugins.sbt            # Plugin declarations
│   └── Build.scala            # Optional .scala build definition
├── src/
│   ├── main/
│   │   ├── scala/           # Scala source files
│   │   ├── java/            # Java source files
│   │   ├── resources/       # Resources (config files, etc.)
│   │   └── scala-2.13/      # Scala version-specific sources
│   └── test/
│       ├── scala/           # Test Scala sources
│       ├── java/            # Test Java sources
│       └── resources/       # Test resources
├── lib/                       # Unmanaged JARs (optional)
├── target/                     # Compiled output (generated)
│   ├── scala-2.13/
│   │   ├── classes/
│   │   └── test-classes/
│   ├── resolution-cache/
│   └── streams/
└── project/target/              # Build output
```

### build.sbt Syntax

#### Basic Settings

```scala
// Project metadata
name := "my-project"
organization := "com.example"
version := "0.1.0-SNAPSHOT"
scalaVersion := "2.13.12"

// Build-wide settings
ThisBuild / organization := "com.example"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.13.12"

// Dependencies
libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.9.0",
  "org.typelevel" %% "cats-effect" % "3.5.0"
)

// Compiler options
scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked",
  "-Xlint"
)

// Java options
javacOptions ++= Seq(
  "-source", "1.8",
  "-target", "1.8"
)
```

#### Project Declarations

```scala
// Simple project
lazy val core = project

// Project with custom directory
lazy val core = (project in file("core"))

// Project with settings
lazy val core = (project in file("core"))
  .settings(
    name := "core",
    libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"
  )

// Project with plugins
lazy val web = (project in file("web"))
  .enablePlugins(JavaAppPackaging)
  .settings(
    name := "web"
  )

// Custom project ID
lazy val api = (project in file("api"))
  .settings(
    name := "api"
  )
```

#### Scopes

```scala
// Configuration scopes (Compile, Test, Runtime, IntegrationTest)
Compile / scalacOptions ++= Seq("-Ywarn-unused")
Test / scalacOptions ++= Seq("-Ywarn-value-discard")

// Task scopes
Compile / compile / scalacOptions ++= Seq("-Werror")
Test / test / fork := true

// Project scopes
core / scalacOptions ++= Seq("-Xlint")
api / libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.17"

// ThisBuild scope (global for build)
ThisBuild / scalacOptions ++= Seq("-deprecation")

// Global scope (all builds)
Global / cancelable := false
```

### Dependencies Management

#### Syntax

```scala
// Basic dependency
libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"

// With double percent %% (adds Scala version)
"org.typelevel" %% "cats-core" % "2.9.0"
// Equivalent to: "org.typelevel" % "cats-core_2.13" % "2.9.0"

// With single percent % (explicit Scala version)
"org.typelevel" % "cats-core_2.13" % "2.9.0"

// Cross-version (supports multiple Scala versions)
libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"
```

#### Configurations

```scala
// Compile scope (default)
libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"

// Test scope
libraryDependencies += "org.scalameta" %% "munit" % "1.0.0" % Test
libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.17" % Test

// Provided scope (compile and test only)
libraryDependencies += "org.apache.spark" %% "spark-core" % "3.5.0" % Provided

// Runtime scope (runtime and test only)
libraryDependencies += "org.slf4j" % "slf4j-simple" % "2.0.9" % Runtime

// Custom configuration
lazy val IntegrationTest = config("it").extend(Test)

libraryDependencies += "com.example" %% "some-lib" % "1.0.0" % IntegrationTest
```

#### Exclusions

```scala
// Exclude single transitive dependency
libraryDependencies ++= Seq(
  "com.example" %% "some-lib" % "1.0.0"
    .exclude("org.slf4j", "slf4j-api")
)

// Exclude multiple transitive dependencies
libraryDependencies ++= Seq(
  "com.example" %% "some-lib" % "1.0.0"
    .exclude("org.slf4j", "slf4j-api")
    .exclude("commons-logging", "commons-logging")
    .exclude("com.esotericsoftware.minlog", "minlog")
)

// Cross-building exclusions
libraryDependencies ~= { deps =>
  deps.map { mod =>
    if (mod.organization == "com.typesafe.play") {
      mod.exclude("commons-logging", "commons-logging")
    } else {
      mod
    }
  }
}
```

#### Version Constraints

```scala
// Fixed version
libraryDependencies += "org.typelevel" %% "cats-core" % "2.9.0"

// Version range (Maven style)
libraryDependencies += "com.example" %% "some-lib" % "[1.0.0,2.0.0)"

// Latest integration
libraryDependencies += "com.example" %% "some-lib" % "latest.integration"

// Latest release
libraryDependencies += "com.example" %% "some-lib" % "latest.release"

// Plus notation (latest 1.x.x)
libraryDependencies += "com.example" %% "some-lib" % "1.+"

// Ivy revision syntax
libraryDependencies += "com.example" %% "some-lib" % "2.9.+"
```

#### Dependency Overrides

```scala
// Force specific version across all dependencies
dependencyOverrides += "org.slf4j" % "slf4j-api" % "2.0.9"
dependencyOverrides += "org.typelevel" %% "cats-core" % "2.9.0"

// Multiple overrides
dependencyOverrides ++= Set(
  "org.slf4j" % "slf4j-api" % "2.0.9",
  "org.typelevel" %% "cats-effect" % "3.5.0"
)
```

### Resolvers

```scala
// Standard resolvers
resolvers += "Sonatype OSS Snapshots" at "https://oss.sonatype.org/content/repositories/snapshots"
resolvers += "Sonatype Releases" at "https://oss.sonatype.org/content/repositories/releases/"

// Local Maven
resolvers += Resolver.mavenLocal
resolvers += "Local Maven" at "file://" + Path.userHome.absolutePath + "/.m2/repository"

// Custom Maven
resolvers += "My Repo" at "https://example.com/maven"

// Ivy repository
resolvers += Resolver.url("My Ivy", url("https://example.com/ivy"))(
  ivyPatterns = Patterns("[organization]/[module]/[revision]/[artifact]-[revision].[ext]")
)

// Bintray (deprecated)
resolvers += Resolver.jcenterRepo
resolvers += Resolver.bintrayRepo("owner", "repo")

// SBT plugin resolver
resolvers += Resolver.sbtPluginRepo("releases")
```

### Build Tasks

#### Common Tasks

```bash
# Basic commands
sbt compile              # Compile all sources
sbt test                 # Run all tests
sbt run                  # Run main class
sbt package               # Create JAR file
sbt clean                # Clean build artifacts

# Dependency management
sbt update               # Update dependencies
sbt reload               # Reload build definition
sbt projects              # List all projects

# Documentation
sbt doc                  # Generate ScalaDoc

# Interactive mode
sbt                     # Enter interactive shell
exit                    # Exit interactive shell

# Batch mode
sbt compile              # Run single command
sbt "compile; test"     # Run multiple commands
```

#### Continuous Execution

```bash
# Re-compile on source changes
sbt ~compile

# Re-run tests on changes
sbt ~test

# Re-run specific test
sbt ~testOnly MyTest

# Stop continuous execution (press Enter)
```

#### Task Inspection

```bash
# Show task information
sbt help compile        # Show task description
sbt inspect compile    # Show task definition and dependencies

# Show settings
sbt show scalacOptions

# Show classpath
sbt show Compile / dependencyClasspath
sbt show Test / dependencyClasspath

# Show dependency tree
sbt dependencyTree
sbt dependencyBrowse
```

### Custom Tasks

```scala
// Define simple task
lazy val hello = taskKey[Unit]("Say hello")

hello := {
  println(s"Hello from ${name.value}!")
}

// Task with inputs
lazy val greet = inputKey[Unit]("Greet someone")

greet := {
  val name = greet.parsed.prompt("Your name: ")
  println(s"Hello, $name!")
}

// Task depending on other tasks
lazy val buildAndHello = taskKey[Unit]("Build and say hello")

buildAndHello := {
  compile.value
  hello.value
}

// Task returning a value
lazy val myValue = taskKey[String]("Compute a value")

myValue := {
  "computed value"
}

// Dynamic task
lazy val dynamicTask = taskKey[Seq[String]]("Dynamic task")

dynamicTask := Def.taskDyn {
  val sources = (Compile / unmanagedSources).value
  if (sources.isEmpty) {
    Def.task(Seq("empty"))
  } else {
    Def.task(sources.map(_.getName))
  }
}.value
```

### Multi-Project Builds

```scala
// Build-wide settings
ThisBuild / organization := "com.example"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.13.12"

// Common settings
lazy val commonSettings = Seq(
  scalacOptions ++= Seq(
    "-deprecation",
    "-feature",
    "-unchecked"
  ),
  libraryDependencies ++= Seq(
    "org.typelevel" %% "cats-core" % "2.9.0"
  )
)

// Multiple projects
lazy val core = (project in file("core"))
  .settings(commonSettings)

lazy val utils = (project in file("utils"))
  .settings(commonSettings)

lazy val api = (project in file("api"))
  .dependsOn(core)
  .aggregate(core)
  .settings(commonSettings)

lazy val web = (project in file("web"))
  .dependsOn(core, utils)
  .settings(commonSettings)

// Root project
lazy val root = (project in file("."))
  .aggregate(core, utils, api, web)
```

#### Inter-Project Dependencies

```scala
// Classpath dependency
lazy val api = (project in file("api"))
  .dependsOn(core)

// Multi-configuration dependency
lazy val api = (project in file("api"))
  .dependsOn(core % "compile->compile;test->test")

// Aggregate (run task on all projects)
lazy val root = (project in file("."))
  .aggregate(core, api, web)

// Per-configuration aggregation (disable some)
lazy val root = (project in file("."))
  .aggregate(core, api, web)
  .settings(
    update / aggregate := false
  )
```

### Publishing

```scala
// Publish settings
publishMavenStyle := true
publishTo := Some(
  if (isSnapshot.value) {
    Resolver.file("file", new File("artifacts/snapshots"))
  } else {
    Resolver.file("file", new File("artifacts/releases"))
  }
)

// Credentials
credentials += Credentials(
  Path.userHome / ".sbt" / ".credentials"
)

// POM settings
pomExtra := (
  <scm>
    <url>https://github.com/example/my-project</url>
    <connection>scm:git:git@github.com:example/my-project.git</connection>
  </scm>
  <developers>
    <developer>
      <id>exampledev</id>
      <name>Example Dev</name>
    </developer>
  </developers>
)
```

```bash
# Publishing commands
sbt publish               # Publish to configured repo
sbt publishLocal          # Publish to local Ivy/Maven
sbt publishSigned         # Publish with GPG signature
```

---

## Scala-CLI Complete Reference

### Installation

```bash
# Using coursier
cs install scala-cli

# Using Homebrew (macOS)
brew install scala-cli

# Verify installation
scala-cli --version
```

### Basic Commands

```bash
# Run Scala file
scala-cli run MyApp.scala

# Compile without running
scala-cli compile MyApp.scala

# Run with specific Scala version
scala-cli --scala 2.13 run MyApp.scala
scala-cli --scala 3.3 run MyApp.scala

# Check Scala version
scala-cli --scala-version

# Run REPL
scala-cli repl

# Evaluate expression
scala-cli eval "1 + 1"
```

### Directives

```scala
//> using scala 3.3.1
//> using lib "org.typelevel::cats-core:2.9.0"
//> using resourceDir ./resources
//> using option "-deprecation"

import cats.implicits._

object Main {
  def main(args: Array[String]): Unit = {
    println("Hello with Cats!")
  }
}
```

#### Available Directives

```scala
//> using scala <version>           // Set Scala version
//> using lib <dep>                // Add library
//> using dependency <dep>          // Add dependency
//> using repository <url>          // Add repository
//> using resourceDir <path>        // Set resource directory
//> using mainClass <class>        // Set main class
//> using option <flag>             // Add compiler option
//> using javacOption <flag>        // Add Java compiler option
//> using target <target>           // Set output directory
//> using platform jvm|js|native    // Set platform
//> using testFramework <name>     // Set test framework
```

### Dependencies

```bash
# Single dependency
scala-cli --dep org.typelevel::cats-core:2.9.0 run MyApp.scala

# Multiple dependencies
scala-cli --dep org.typelevel::cats-core:2.9.0 \
              --dep org.typelevel::cats-effect:3.5.0 \
              run MyApp.scala

# Scala 2 dependencies (use ::)
scala-cli --dep org.scalacheck::scalacheck:1.17.0 run MyApp.scala

# Toolkit (batteries-included)
scala-cli --toolkit default run MyApp.scala
scala-cli --toolkit test test

# Using test dependencies
scala-cli --test --dep org.scalameta::munit:1.0.0 test
```

### Project Mode

```bash
# Create new project
scala-cli new my-app

# Create project from template
scala-cli new scala/scala-seed.g8 my-app

# Set up existing directory
scala-cli --setup .

# Compile project
scala-cli compile .

# Run project
scala-cli run .

# Run tests
scala-cli test .

# Package project
scala-cli package .
scala-cli --library package .

# Format code
scala-cli fmt .
scala-cli fmt --check .
```

### Cross-Platform

```bash
# Compile for JavaScript
scala-cli --platform js compile .
scala-cli --platform js run .

# Compile for Native
scala-cli --platform native compile .
scala-cli --platform native run .

# Create universal distribution
scala-cli --js --native --jvm package .
```

### Testing

```bash
# Run all tests
scala-cli test

# Run specific test
scala-cli test --test-only MyTest

# Watch mode (re-run on changes)
scala-cli test --watch

# Test with coverage
scala-cli test --coverage
```

---

## SBT Plugins Reference

### sbt-assembly

**Purpose**: Create fat JARs (über-jars) with all dependencies included.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.5")
```

**Basic Usage**:

```scala
// build.sbt
lazy val app = project
  .settings(
    assembly / mainClass := Some("com.example.Main"),
    assembly / assemblyJarName := "my-app.jar"
  )
```

```bash
sbt assembly
```

**Merge Strategies**:

```scala
// Default strategy for specific files
ThisBuild / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) =>
    MergeStrategy.discard
  case x =>
    val oldStrategy = (ThisBuild / assemblyMergeStrategy).value
    oldStrategy(x)
}

// Available strategies:
MergeStrategy.first              // Use first matching file
MergeStrategy.last               // Use last matching file
MergeStrategy.deduplicate        // Verify all files are identical
MergeStrategy.concat             // Concatenate all matching files
MergeStrategy.filterDistinctLines // Concatenate, removing duplicates
MergeStrategy.rename            // Rename conflicting files
MergeStrategy.discard            // Discard matching files
MergeStrategy.singleOrError      // Fail on conflict
```

**Excluding Scala Library**:

```scala
lazy val app = project
  .settings(
    assemblyPackageScala / assembleArtifact := false
  )
```

**Excluding Dependencies**:

```scala
lazy val app = project
  .settings(
    assemblyPackageDependency / assembleArtifact := false
  )
```

**Shading**:

```scala
// Rename packages to avoid conflicts
ThisBuild / assemblyShadeRules := Seq(
  ShadeRule.rename("org.apache.commons.io.**" -> "shadeio.@1").inAll
)
```

**Cache Control**:

```scala
// Disable caching
ThisBuild / assemblyCacheOutput := false

// Disable repeatable build (faster, non-deterministic)
ThisBuild / assemblyRepeatableBuild := false
```

---

### sbt-native-packager

**Purpose**: Create native packages (Debian, RPM, Docker, MSI, etc.).

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.github.sbt" % "sbt-native-packager" % "1.9.4")
```

**Java Application**:

```scala
// build.sbt
lazy val app = project
  .enablePlugins(JavaAppPackaging)
  .settings(
    maintainer := "Example Dev",
    packageSummary := "My Application",
    packageDescription := "A sample application"
  )
```

**Java Server Application**:

```scala
// build.sbt
lazy val server = project
  .enablePlugins(JavaServerAppPackaging)
  .settings(
    maintainer := "Example Dev",
    daemonUser := "myapp",
    daemonGroup := "myapp"
  )
```

**Packaging Commands**:

```bash
sbt Universal/packageBin    # Create universal zip/tar.gz
sbt Debian/packageBin       # Create Debian package
sbt Rpm/packageBin          # Create RPM package
sbt Windows/packageBin     # Create Windows MSI
sbt Docker/publishLocal     # Create Docker image
sbt GraalVMNativeImage/packageBin  # Create native binary
```

**Docker Configuration**:

```scala
// build.sbt
lazy val app = project
  .enablePlugins(JavaAppPackaging)
  .settings(
    Docker / maintainer := "Example Dev",
    Docker / packageName := "myapp",
    Docker / version := "latest",
    dockerBaseImage := "openjdk:17-jre-slim"
  )
```

**Systemd Configuration**:

```scala
// build.sbt
lazy val server = project
  .enablePlugins(JavaServerAppPackaging)
  .settings(
    Universal / daemonUser := "myapp",
    Universal / daemonGroup := "myapp",
    Universal / daemonStdoutLogFile := "/var/log/myapp/stdout.log",
    Universal / daemonStderrLogFile := "/var/log/myapp/stderr.log"
  )
```

---

### sbt-scoverage

**Purpose**: Measure test coverage using scoverage.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("org.scoverage" % "sbt-scoverage" % "2.0.7")
```

**Basic Usage**:

```bash
sbt clean coverage test          # Run tests with coverage
sbt coverageReport            # Generate coverage reports
sbt coverageAggregate         # Aggregate multi-project reports
```

**Configuration**:

```scala
// build.sbt
coverageEnabled := true

// Minimum coverage thresholds
coverageMinimumStmtTotal := 90
coverageMinimumBranchTotal := 80
coverageMinimumStmtPerPackage := 85
coverageMinimumBranchPerPackage := 75
coverageMinimumStmtPerFile := 80
coverageMinimumBranchPerFile := 70

// Fail build on minimum not met
coverageFailOnMinimum := true

// Exclude packages
coverageExcludedPackages := "Reverse.*;models\\.data.*"

// Exclude files
coverageExcludedFiles := ".*\\/test\\/.*"

// Output directory
coverageDataDir := target.value / "custom-coverage"
```

**Inline Exclusions**:

```scala
// $COVERAGE-OFF$
// ... code to exclude ...
// $COVERAGE-ON$
```

---

### sbt-git

**Purpose**: Git integration for versioning and prompts.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.github.sbt" % "sbt-git" % "2.0.0")
```

**Git Versioning**:

```scala
// build.sbt
enablePlugins(GitVersioning)

git.baseVersion := "0.1.0"

// Custom version formatting
git.formattedShaVersion := git.gitHeadCommit.value map { sha => s"v$sha" }
git.formattedDateVersion := {
  val format = new java.text.SimpleDateFormat("yyyyMMdd-HHmmss")
  format.format(new java.util.Date())
}

// Git describe versioning
git.useGitDescribe := true
git.gitDescribePatterns := Seq("v*")
```

**Git Branch Prompt**:

```scala
// build.sbt
enablePlugins(GitBranchPrompt)
```

**Git Commands**:

```bash
# Run git commands from sbt shell
sbt git status
sbt git log --oneline -5
sbt git branch
```

**JGit Configuration**:

```scala
// build.sbt
useJGit := true           // Force JGit
useReadableConsoleGit := true  // Force git executable
```

---

### sbt-scalafmt

**Purpose**: Code formatting using Scalafmt.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.0")
```

**Basic Usage**:

```bash
sbt scalafmt      # Format all sources
sbt scalafmtCheck  # Check formatting
sbt scalafmtSbt    # Format build.sbt
```

**Configuration**:

```scala
// build.sbt
scalafmtOnCompile := true       // Format on compile
scalafmtCheckOnCompile := true // Check formatting on compile

// Custom configuration
scalafmtConfig := Some(file(".scalafmt.conf"))
```

**Configuration File** (`.scalafmt.conf`):

```hocon
version = "3.8.0"
maxColumn = 100
align.preset = more
align.tokens = [
  {code = "%", owner = "If"}
  {code = "%%", owner = "Apply"}
]
assumeStandardLibraryStripMargin = true
danglingParentheses.preset = true
rewrite.rules = [
  RedundantBraces
  RedundantParens
  SortImports
]
```

---

### sbt-buildinfo

**Purpose**: Generate build information (version, git SHA, etc.) as source code.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.eed3si9n" % "sbt-buildinfo" % "0.11.0")
```

**Basic Usage**:

```scala
// build.sbt
lazy val myProject = project
  .enablePlugins(BuildInfoPlugin)
  .settings(
    buildInfoKeys := Seq[BuildInfoKey](name, version, scalaVersion, sbtVersion),
    buildInfoPackage := "com.example.myproject",
    buildInfoObject := "BuildInfo"
  )
```

**Generated Code**:

```scala
// Automatically generated in: src/main/scala/com/example/myproject/BuildInfo.scala
package com.example.myproject

object BuildInfo {
  val name: String = "my-project"
  val version: String = "0.1.0-SNAPSHOT"
  val scalaVersion: String = "2.13.12"
  val sbtVersion: String = "1.9.3"
}
```

**Custom Keys**:

```scala
// build.sbt
lazy val myProject = project
  .enablePlugins(BuildInfoPlugin)
  .settings(
    buildInfoKeys := Seq[BuildInfoKey](name, version, scalaVersion, sbtVersion),
    buildInfoPackage := "com.example.myproject",
    buildInfoObject := "BuildInfo",
    buildInfoOptions ++= Seq(
      BuildInfoOption.BuildTime,
      BuildInfoOption.ToJson,
      BuildInfoOption.ToMap
    )
  )
```

---

### sbt-jmh

**Purpose**: Java Microbenchmark Harness (JMH) integration.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("pl.project13.scala" % "sbt-jmh" % "0.4.5")
```

**Basic Usage**:

```bash
sbt jmh:run            # Run benchmarks
sbt jmh:compile         # Compile benchmarks
```

**Project Structure**:

```
src/
├── jmh/
│   └── scala/           # Benchmark sources
├── main/
│   └── scala/           # Main sources
└── test/
    └── scala/           # Test sources
```

**Example Benchmark**:

```scala
// src/jmh/scala/example/Benchmark.scala
import org.openjdk.jmh.annotations._
import java.util.concurrent.TimeUnit

@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
class MyBenchmark {
  @Benchmark
  def benchmark: Unit = {
    // Benchmark code here
  }
}
```

---

### sbt-web

**Purpose**: Web application packaging and asset management.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.typesafe.sbt" % "sbt-web" % "1.4.4")
```

**Basic Usage**:

```bash
sbt WebKeys.packageBin  # Package web assets
```

**Configuration**:

```scala
// build.sbt
lazy val web = project
  .enablePlugins(SbtWeb)
  .settings(
    WebKeys.packagePrefix := "webapp",
    WebKeys.stagingDirectory := target.value / "web-stage"
  )
```

---

### sbt-protobuf

**Purpose**: Protocol Buffers compilation.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.thesamet" % "sbt-protobuf" % "0.6.5")
```

**Basic Usage**:

```bash
sbt protobufGenerate     # Generate Scala from .proto files
```

**Configuration**:

```scala
// build.sbt
Compile / PB.targets := Seq(
  scalapb.gen(
    target.value / "protobuf-generated",
    flatPackage("com.example")
  )
)

Compile / PB.protoSources += sourceDirectory.value / "protobuf"
```

---

### sbt-pgp

**Purpose**: PGP signing for publishing.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.jsuereth" % "sbt-pgp" % "2.2.1")
```

**Basic Usage**:

```bash
sbt publishSigned      # Publish with PGP signatures
sbt PgpSigner        # Sign artifacts
```

**Configuration**:

```scala
// build.sbt
pgpPassphrase := sys.env.get("PGP_PASSPHRASE")
pgpSecretRing := file("/home/user/.gnupg/secring.gpg")
pgpPublicRing := file("/home/user/.gnupg/pubring.gpg")

useGpg := false        // Use Bouncy Castle instead of gpg
useGpgAgent := true    // Use gpg-agent
```

---

### sbt-dynver

**Purpose**: Dynamic versioning from Git.

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("com.dwijnand" % "sbt-dynver" % "5.0.1")
```

**Basic Usage**:

```bash
sbt dynver       # Update version from git
```

**Configuration**:

```scala
// build.sbt
dynverSeparator := "-"
dynverVTagPrefix := "v"
dynverGitDescribeOutput := true
dynverSonatypeSnapshots := true
```

---

## Cross-Platform Reference

### Scala.js

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("org.portable-scala" % "sbt-scalajs-crossproject" % "1.2.0")
```

**Cross Project Setup**:

```scala
// build.sbt
lazy val core = crossProject(JSPlatform, JVMPlatform)
  .crossType(CrossType.Full)
  .settings(
    name := "core",
    libraryDependencies ++= Seq(
      "org.typelevel" %% "cats-core" % "2.9.0"
    )
  )
  .jsSettings(
    scalaJSUseMainModuleInitializer := true,
    scalaJSLinkerConfig ~= { _.withModuleKind(ModuleKind.CommonJSModule) }
  )
  .jvmSettings(
    // JVM-specific settings
  )

lazy val coreJS = core.js
lazy val coreJVM = core.jvm
```

**Commands**:

```bash
# Compile Scala.js
sbt coreJS/compile

# Run tests
sbt coreJS/test

# Optimize
sbt coreJS/fastOptJS    # Development build (faster)
sbt coreJS/fullOptJS    # Production build (slower, optimized)

# Launch browser
sbt coreJS/fastLinkJS

# Generate source maps
sbt coreJS/fastOptJS::sourceMap
```

**Module Kinds**:

```scala
// build.sbt
.jsSettings(
  scalaJSLinkerConfig ~= { _.withModuleKind(ModuleKind.CommonJSModule) }
  // ModuleKind.CommonJSModule
  // ModuleKind.ESModule
  // ModuleKind.NoModule
)
```

**Node.js Integration**:

```scala
// build.sbt
.jsSettings(
  scalaJSUseMainModuleInitializer := true,
  Test / scalaJSUseMainModuleInitializer := true,
  // Test / fork := false  // Run tests in JVM runner
)
```

---

### Scala Native

**Installation**:

```scala
// project/plugins.sbt
addSbtPlugin("org.portable-scala" % "sbt-scala-native" % "0.4.0")
```

**Native Project Setup**:

```scala
// build.sbt
lazy val nativeCore = nativeProject("core")
  .settings(
    name := "core-native",
    libraryDependencies ++= Seq(
      "org.typelevel" %% "cats-core" % "2.9.0"
    )
  )
```

**Commands**:

```bash
sbt nativeCore/compile
sbt nativeCore/run
sbt nativeCore/test
```

**Configuration**:

```scala
// build.sbt
.nativeSettings(
  nativeLink := {
    val options = (nativeLink / nativeLink).value
    options.withLogging(logger => new NativeBuildLogger {
      def debug(msg: String): Unit = logger.debug(msg)
      def info(msg: String): Unit = logger.info(msg)
      def warn(msg: String): Unit = logger.warn(msg)
      def error(msg: String): Unit = logger.error(msg)
    })
  }
)
```

---

## Migration Patterns

### Scala 2 to 3 Migration

**Key Changes**:

```scala
// Scala 2.13
def foo(x: Int): Int = x * 2

// Scala 3 (can use braces or not)
def foo(x: Int): Int =
  x * 2
```

**Syntax Changes**:

```scala
// Scala 2.13 - Syntax using `import`
import cats.implicits._

// Scala 3 - Using `given` and `import`
import cats.implicits.given

// Scala 2.13 - Context bounds
def foo[F[_]: Monad](F: Monad[F]): F[Int]

// Scala 3 - Using clauses
def foo[F[_]]: Monad: F[Int]
```

**Collection Changes**:

```scala
// Scala 2.13
import scala.collection.immutable._

// Scala 3 (imports reorganized)
import scala.collection.*

// New Scala 3 collections
import scala.collection.mutable.{ArrayBuffer => AB}

// Scala 3 new: scala.collection.mutable.ArrayDeque
import scala.collection.mutable.ArrayDeque
```

**Optional Braces**:

```scala
// Scala 2.13
object Foo {
  def bar(): Unit = {
    println("hello")
  }
}

// Scala 3 (braces optional)
object Foo:
  def bar(): Unit =
    println("hello")
```

**Given/Using**:

```scala
// Scala 2.13
implicit val ord: Ordering[Int] = Ordering.Int

def sorted(list: List[Int]): List[Int] =
  list.sorted

// Scala 3
given Ordering[Int] = Ordering.Int

def sorted(list: List[Int]): List[Int] =
  list.sorted
```

**Cross-Compilation**:

```scala
// build.sbt
ThisBuild / crossScalaVersions := Seq("2.13.12", "3.3.1")

lazy val myProject = crossProject(JSPlatform, JVMPlatform)
  .crossType(CrossType.Full)
  .settings(
    name := "my-project",
    libraryDependencies ++= Seq(
      "org.typelevel" %% "cats-core" % "2.9.0"
    )
  )
```

**Version-Specific Code**:

```scala
// src/main/scala-2.13/example/Foo.scala
// Scala 2.13 specific code
package example

object Foo {
  def hello(): Unit = println("Hello from 2.13!")
}
```

```scala
// src/main/scala-3/example/Foo.scala
// Scala 3 specific code
package example

object Foo {
  def hello(): Unit = println("Hello from 3!")
}
```

---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Scala
        uses: olafurpgio/setup-scala@v13
        with:
          java-version: 'temurin:17'

      - name: Cache SBT
        uses: actions/cache@v3
        with:
          path: |
            ~/.sbt
            ~/.ivy2/cache
            ~/.coursier/cache/v1
            ~/.cache/coursier/v1
          key: ${{ runner.os }}-sbt-${{ hashFiles('**/*.sbt') }}

      - name: Compile
        run: sbt compile

      - name: Test
        run: sbt test

      - name: Package
        run: sbt package
```

### GitLab CI

```yaml
# .gitlab-ci.yml
image: hseeberger/scala-sbt:latest

variables:
  SBT_VERSION: "1.9.3"
  SCALA_VERSION: "2.13.12"

stages:
  - compile
  - test
  - package

compile:
  stage: compile
  script:
    - sbt compile

test:
  stage: test
  script:
    - sbt test

package:
  stage: package
  script:
    - sbt package
  artifacts:
    paths:
      - target/**/*.jar
    expire_in: 1 week
```

---

## Performance Optimization

### Parallel Builds

```bash
# Enable parallel execution
sbt -J-Xmx4G -Dbuild.parallel=2 compile
```

### Caching

```scala
// build.sbt
// Enable remote caching
pushRemoteCacheTo := Some("https://example.com/cache")
pullRemoteCache := true

// Local caching
ThisBuild / useCoursier := true
```

### Incremental Compilation

```bash
# Clean and recompile
sbt clean compile

# Skip internal dependency tracking (for large projects)
ThisBuild / trackInternalDependencies := TrackLevel.TrackIfMissing
```

### JVM Options

```bash
# Set JVM memory
sbt -J-Xmx4G

# Set JVM options
sbt -J-XX:+UseG1GC -J-XX:MaxGCPauseMillis=200
```

---

## Additional Resources

- [SBT Documentation](https://www.scala-sbt.org/1.x/docs/)
- [Scala-CLI Documentation](https://scala-cli.virtuslab.org/)
- [SBT Assembly](https://github.com/sbt/sbt-assembly)
- [SBT Native Packager](https://sbt-native-packager.readthedocs.io/)
- [Scalafmt](https://scalameta.org/scalafmt/)
- [Scala.js](https://www.scala-js.org/)
- [Scala Native](https://scala-native.org/)
