# Scope System and Settings Reference

## Scope Delegation Chain

When sbt looks up a key, it searches in this order (first match wins):

```
subproject / configuration / task / key
subproject / configuration / key
ThisBuild / configuration / task / key
ThisBuild / configuration / key
Zero / configuration / task / key
Global / key
```

`inspect` shows where a value actually comes from:
```bash
> inspect scalacOptions          # Shows delegation chain + actual source
> inspect tree scalacOptions     # Full dependency tree with types
> inspect actual scalacOptions   # Resolved value after delegation
```

### Configuration Axis Values

| Config | Purpose |
|---|---|
| `Compile` | Main sources (`src/main/`) |
| `Test` | Test sources (`src/test/`) |
| `Runtime` | Runtime classpath (includes Compile + runtime deps) |
| `IntegrationTest` | Integration tests (requires custom config in sbt 1.x, removed in sbt 2.x) |

### Common Scoping Mistakes

```scala
// WRONG — creates a new task at Zero/Zero/Zero, doesn't override standard compile
compile := { ... }

// CORRECT — overrides the standard Compile compile
Compile / compile := { ... }

// WRONG — references wrong scope when mixing scoped keys
fullClasspath := fullClasspath.value.filterNot(...)

// CORRECT — both sides use same scope
Compile / fullClasspath := (Compile / fullClasspath).value.filterNot(...)
```

## Setting vs Task vs Input Key Types

| Type | Evaluated | Can depend on | Example |
|---|---|---|---|
| `SettingKey[A]` | Once at load time | Other settings | `name`, `scalaVersion`, `libraryDependencies` |
| `TaskKey[A]` | Every invocation | Settings + tasks | `compile`, `test`, `run` |
| `InputKey[A]` | Every invocation with parsed input | Settings + tasks | `runMain`, `testOnly` |

**Critical**: You cannot depend on a task from a setting. Settings are fixed at load time; tasks run on demand.

```scala
// WRONG — setting depending on task
name := (compile.value.toString)  // Error: can't depend on task from setting

// CORRECT — task depending on setting
compile := {
  val projectName = name.value    // OK: task reads setting
  println(s"Compiling $projectName")
}
```

## The `.value` Macro

`.value` is NOT a normal method call — it's a macro that:
1. Creates a dependency edge in the task graph
2. Extracts the value at execution time
3. Ensures the dependency runs first

```scala
Compile / compile := {
  val projectName = name.value       // dependency on name
  val deps = libraryDependencies.value  // dependency on libraryDependencies
  // compile depends on both name and libraryDependencies
}
```

`.value` calls can appear anywhere in the body (top-level, in if branches, in match cases) — the macro hoists them all to the beginning.

## sbt 2.x Common Settings

In sbt 2.x, bare settings (not wrapped in `.settings(...)`) are "common settings" injected into ALL subprojects:

```scala
// build.sbt (sbt 2.x)
scalaVersion := "3.3.3"  // Applies to ALL subprojects automatically
```

In sbt 1.x, this only applied to the root project. This fixes the "dynamic dispatch problem" — a task like `hi := name.value + "!"` now correctly returns each subproject's own name.

**Override hierarchy** (most specific wins):
1. Project `.settings(...)` — per-project overrides
2. Common settings (bare in build.sbt)
3. Plugin defaults
4. `ThisBuild`-scoped settings (delegation fallback)
5. `Global`-scoped settings

## Custom Task Definitions

```scala
// Simple task
val greeting = taskKey[String]("A greeting")
greeting := s"Hello, ${name.value}!"

// Task that depends on other tasks
val myCompile = taskKey[Unit]("Custom compile with greeting")
myCompile := {
  val msg = greeting.value
  println(msg)
  (Compile / compile).value
}

// Input task with argument parsing
val runWithArgs = inputKey[Unit]("Run with custom args")
runWithArgs := {
  val args = spaceDelimited("<args>").parsed
  println(s"Running with: ${args.mkString(" ")}")
  (Compile / run).toTask("").value
}
```

## Auto-Reload on Build Changes

```scala
// Auto-detect build.sbt changes and reload
Global / onChangedBuildSource := ReloadOnSourceChanges

// Options: ReloadOnSourceChanges | IgnoreSourceChanges | FailOnSourceChanges
```

## `.sbtrc` — Startup Aliases

```bash
# ~/.sbtrc or <project>/.sbtrc — commands executed on shell startup
alias ci = ;clean;compile;test
alias fmt = ;scalafmt;scalafmtSbt
```
