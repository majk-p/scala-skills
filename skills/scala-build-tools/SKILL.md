---
name: scala-build-tools
description: Use this skill when building, compiling, testing, or packaging Scala projects. This includes project configuration with sbt or scala-cli, managing dependencies, build tasks, packaging, cross-compilation, and Scala 2 to 3 migration. Trigger when the user mentions sbt, scala-cli, building, compiling, dependencies, or needs to set up a Scala project.
---

# Build Tools for Scala

This skill covers Scala build tools including sbt, scala-cli, and essential sbt plugins for project configuration, dependency management, compilation, testing, packaging, and cross-platform builds.

> **Note**: Version numbers in examples are illustrative. Always check for the latest version before using.

## Overview

Scala projects use build tools to manage:
- **Project structure** - Source files, resources, and configuration
- **Dependencies** - Library resolution and version management
- **Build tasks** - Compile, test, package, run
- **Packaging** - JARs, native distributions, Docker images
- **Cross-platform** - JVM, Scala.js, Scala Native
- **CI/CD** - Continuous integration workflows

## Quick Start

### sbt

```scala
// build.sbt
ThisBuild / organization := "com.example"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.13.12"

lazy val myProject = project
  .settings(
    name := "my-project",
    libraryDependencies ++= Seq(
      "org.typelevel" %% "cats-core" % "2.9.0",
      "org.scalameta" %% "munit" % "1.0.0" % Test
    )
  )
```

### scala-cli

```bash
# Compile and run a file
scala-cli run MyApp.scala

# Compile with dependencies
scala-cli --dep org.typelevel::cats-core:2.9.0 run MyApp.scala

# Run tests
scala-cli test
```

## SBT Core Patterns

### Project Structure

```
my-project/
├── build.sbt              # Main build definition
├── project/
│   ├── build.properties    # sbt version
│   └── plugins.sbt        # SBT plugins
├── src/
│   ├── main/
│   │   ├── scala/       # Main source files
│   │   └── resources/    # Main resources
│   └── test/
│       ├── scala/       # Test source files
│       └── resources/    # Test resources
└── target/               # Compiled output
```

### Dependencies

```scala
// Single dependency
libraryDependencies += "org.typelevel" %% "cats-effect" % "3.5.0"

// Multiple dependencies
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.9.0",
  "org.typelevel" %% "cats-effect" % "3.5.0"
)

// Test-only
libraryDependencies += "org.scalameta" %% "munit" % "1.0.0" % Test

// Provided (runtime excluded)
libraryDependencies += "org.apache.spark" %% "spark-core" % "3.5.0" % Provided
```

### Common Build Tasks

```bash
sbt compile              # Compile all sources
sbt test                 # Run all tests
sbt run                  # Run main class
sbt package              # Create JAR file
sbt clean                # Clean build artifacts
sbt reload               # Reload build definition
sbt update               # Update dependencies

# Continuous execution
sbt ~compile             # Re-compile on source changes
sbt ~test                # Re-run tests on changes
```

## Scala-CLI Core Patterns

### Using Directives

```scala
//> using lib "org.typelevel::cats-core:2.9.0"
//> using scala 3.3.1

import cats.implicits._

object Main {
  def main(args: Array[String]): Unit = {
    println("Hello with Cats!")
  }
}
```

### Project Mode

```bash
scala-cli new my-app     # Create a simple project
scala-cli compile .      # Compile project
scala-cli run .          # Run project
```

## Common SBT Plugins

### sbt-assembly — Fat JARs

```scala
// project/plugins.sbt
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.1.5")

// build.sbt
lazy val app = project
  .settings(
    assembly / mainClass := Some("com.example.Main"),
    assembly / assemblyJarName := "my-app.jar"
  )
```

### sbt-native-packager — Native Packaging

```scala
// project/plugins.sbt
addSbtPlugin("com.github.sbt" % "sbt-native-packager" % "1.9.4")

// build.sbt
lazy val app = project
  .enablePlugins(JavaAppPackaging)
```

```bash
sbt Universal/packageBin    # Create universal zip/tar.gz
sbt Debian/packageBin       # Create Debian package
sbt Docker/publishLocal     # Create Docker image
```

### sbt-scoverage — Code Coverage

```scala
addSbtPlugin("org.scoverage" % "sbt-scoverage" % "2.0.7")
```

```bash
sbt clean coverage test     # Run tests with coverage
sbt coverageReport          # Generate coverage reports
```

### sbt-scalafmt — Code Formatting

```scala
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.0")

// build.sbt
scalafmtOnCompile := true
```

## Cross-Platform Builds

### Scala.js

```scala
lazy val core = crossProject(JSPlatform, JVMPlatform)
  .crossType(CrossType.Full)
  .settings(name := "core")
  .jsSettings(scalaJSUseMainModuleInitializer := true)

lazy val coreJS = core.js
lazy val coreJVM = core.jvm
```

### Scala Native

```scala
lazy val nativeCore = nativeProject("core")
  .settings(name := "core-native")
```

## Multi-Project Builds

```scala
lazy val commonSettings = Seq(
  scalaVersion := "2.13.12",
  scalacOptions ++= Seq("-deprecation", "-feature")
)

lazy val core = (project in file("core")).settings(commonSettings)
lazy val api = project
  .dependsOn(core)
  .aggregate(core)
  .settings(commonSettings)
```

## Choosing the Right Tool

### Use sbt When
- Building multi-module projects
- Need complex build configuration
- Using Scala.js or Scala Native extensively
- Publishing to Maven/Ivy repositories

### Use scala-cli When
- Writing scripts or small utilities
- Learning Scala or a new library
- Creating single-module applications
- Need quick compilation and execution

## Common Patterns

### Dependency Version Conflicts

```scala
// Force specific version
dependencyOverrides += "org.slf4j" % "slf4j-api" % "2.0.9"
```

### Custom Tasks

```scala
lazy val hello = taskKey[Unit]("Say hello")

hello := {
  println(s"Hello from ${name.value}!")
}
```

### Conditional Settings

```scala
scalacOptions ++= {
  CrossVersion.partialVersion(scalaVersion.value) match {
    case Some((2, 13)) => Seq("-Ywarn-unused")
    case Some((3, _))  => Seq("-Wconf:cat=unused")
    case _            => Seq.empty
  }
}
```

## Migration: Scala 2 to 3

Key differences: optional braces, new given/import syntax, opaque types, context functions.

```scala
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

## Dependencies

```scala
// Check for latest versions when adding dependencies
libraryDependencies ++= Seq(
  "org.typelevel" %% "cats-core" % "2.9.0",
  "org.scalameta" %% "munit" % "1.0.0" % Test
)
```

## Related Skills

- **scala-lang** — for Scala language fundamentals and syntax patterns
- **scala-sbt** — sbt vs sbtn usage, server lifecycle, when to reload/restart after build file changes
- **scala-code-quality** — for formatting, linting, and refactoring integration with sbt
- **scala-code-generation** — for metaprogramming and macro-related build configuration

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/REFERENCE.md** — Complete sbt syntax and tasks reference, full Scala-CLI commands and directives, detailed plugin configurations, cross-compilation patterns, migration guides, CI/CD integration examples
