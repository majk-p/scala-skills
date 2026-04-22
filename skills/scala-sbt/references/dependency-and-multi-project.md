# Dependency Management and Multi-Project Builds

## Dependency Operators

| Operator | Behavior | Use Case |
|---|---|---|
| `%` | Raw artifact ID, no suffix | Java libraries: `"com.google.guava" % "guava" % "33.0.0"` |
| `%%` | Appends `_2.13` or `_3` suffix | Scala libraries: `"org.typelevel" %% "cats-core" % "2.9.0"` |

### Cross-Building with %%

`%%` automatically picks the correct binary version for the current Scala:

```scala
// With scalaVersion := "2.13.14"
"org.typelevel" %% "cats-core" % "2.9.0"  // resolves to cats-core_2.13

// With scalaVersion := "3.3.3"
"org.typelevel" %% "cats-core" % "2.9.0"  // resolves to cats-core_3
```

### CrossVersion Strategies

```scala
// Use 2.13 artifact when compiling with Scala 3 (for apps, not libraries)
libraryDependencies += ("org.typelevel" %% "cats-core" % "2.9.0").cross(CrossVersion.for3Use2_13)

// Use Scala 3 artifact when compiling with 2.13
libraryDependencies += ("org.foo" %% "bar" % "1.0.0").cross(CrossVersion.for2_13Use3)

// Full version suffix (for compiler plugins)
libraryDependencies += ("org.typelevel" % "kind-projector" % "0.13.3").cross(CrossVersion.full)
```

## Resolvers

```scala
// Add a Maven repository
resolvers += "Sonatype Releases" at "https://repo1.maven.org/maven2/"

// Add resolver for specific dependency only
libraryDependencies += ("org.foo" %% "bar" % "1.0.0")
  .repositories("Sonatype Snapshots" at "https://s01.oss.sonatype.org/content/repositories/snapshots/")

// Override ALL resolvers (replaces defaults)
externalResolvers := Seq(
  "Maven Central" at "https://repo1.maven.org/maven2/",
  Resolver.mavenLocal
)
```

**Global resolver override** (affects all projects, no build.sbt changes):
```properties
# ~/.sbt/repositories
[repositories]
local
maven-central: https://repo1.maven.org/maven2/
```
```bash
# Enable with: sbt -Dsbt.override.build.repos=true
```

## Eviction and Version Compatibility

sbt (1.5+) fails the build when it detects binary-incompatible dependency eviction:

```scala
// Declare your version scheme so downstream can detect incompatibility
versionScheme := Some("early-semver")

// Options: "early-semver", "pvp", "semver-spec", "strict"
```

**Override eviction errors**:
```scala
// Downgrade eviction to warning
evictionErrorLevel := Level.Info

// Skip eviction check for specific module
libraryDependencySchemes += "org.foo" %% "bar" % VersionScheme.Always
```

## BOM Support (sbt 2.x)

```scala
// Import a Maven BOM for version management
libraryDependencies += ("com.fasterxml.jackson" % "jackson-bom" % "2.21.0").pomOnly()
libraryDependencies += "com.fasterxml.jackson.core" % "jackson-core" % "*"  // version from BOM
```

## Multi-Project Patterns

### Basic Multi-Module

```scala
lazy val root = (project in file("."))
  .aggregate(core, api)
  .settings(
    publish / skip := true    // Don't publish the root project
  )

lazy val core = (project in file("core"))
  .settings(
    name := "my-app-core",
    libraryDependencies ++= Dependencies.coreDeps
  )

lazy val api = (project in file("api"))
  .dependsOn(core)
  .settings(
    name := "my-app-api",
    libraryDependencies ++= Dependencies.apiDeps
  )
```

### Test-to-Compile Dependency

```scala
// api's tests can see core's main sources (not test sources)
.dependsOn(core % "test->compile")

// api's tests can see core's tests (shared test utilities)
.dependsOn(core % "test->test")
```

### Conditional Project Skipping

```scala
// Skip a project under certain Scala versions
lazy val legacyModule = (project in file("legacy"))
  .settings(
    skip := (scalaVersion.value.startsWith("3.")),
    ideSkipProject := (scalaVersion.value.startsWith("3.")),
  )
```

### Cross-Building with projectMatrix

```scala
// sbt 2.x / sbt-projectmatrix plugin
lazy val core = (projectMatrix in file("core"))
  .settings(
    name := "core",
  )
  .jvmPlatform(scalaVersions = Seq("3.3.3", "2.13.14"))

// sbt query to run tests on all Scala 3 subprojects
// sbtn "...@scalaBinaryVersion=3/test"
```

## Centralized Dependencies Pattern

```scala
// project/Dependencies.scala
import sbt._

object Dependencies {
  // Versions
  val catsVersion      = "2.9.0"
  val catsEffectVersion = "3.5.7"
  val circeVersion     = "0.14.6"
  val munitVersion     = "1.0.0"

  // Libraries
  val catsCore   = "org.typelevel" %% "cats-core"    % catsVersion
  val catsEffect = "org.typelevel" %% "cats-effect"  % catsEffectVersion
  val circeCore  = "io.circe"      %% "circe-core"   % circeVersion
  val circeGeneric = "io.circe"    %% "circe-generic" % circeVersion

  // Groups
  val coreDeps = Seq(catsCore, catsEffect)
  val jsonDeps = Seq(circeCore, circeGeneric)
  val testDeps = Seq(
    "org.scalameta" %% "munit" % munitVersion % Test
  )
}
```

```scala
// build.sbt
import Dependencies._

lazy val core = project.settings(
  libraryDependencies ++= coreDeps ++ jsonDeps ++ testDeps
)
```

## Publishing

```scala
// Skip publishing for root/aggregate projects
publish / skip := true

// Declare compatibility scheme for downstream consumers
versionScheme := Some("early-semver")

// Publish target
publishTo := Some("GitHub Packages" at "https://maven.pkg.github.com/org/repo")

// Credentials from file
credentials += Credentials(Path.userHome / ".sbt" / ".credentials")

// Local testing
// sbtn publishLocal   → ~/.ivy2/local/
// sbtn publishM2      → ~/.m2/repository/
```
