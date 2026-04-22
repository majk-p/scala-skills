---
name: scala-sbt
description: "Use this skill for day-to-day sbt and sbtn usage — the operational side of Scala's build tool. This is NOT about setting up new projects (see scala-build-tools for that). This covers: sbt vs sbtn architecture and when to use each, server lifecycle (when to reload vs restart), the settings DSL operators, the scope system, shell commands, incremental compilation behavior, and troubleshooting stale builds or confusing errors. Load this skill whenever the user is working inside an sbt project and running into issues like 'changes not taking effect', 'sbt is slow', 'how do I inspect a setting', or needs to understand sbt's DSL, scoping, or task system — even if they don't mention sbtn or server architecture by name."
---

# sbt / sbtn — Operational Guide

This skill covers working with sbt on existing projects: running commands, understanding the DSL, debugging issues, and managing the server lifecycle. For creating new projects, adding plugins, or configuring packaging, see **scala-build-tools** instead.

## First Thing: Check the sbt Version

sbt 1.x and 2.x have significant behavioral differences. Before doing anything, check:

```bash
cat project/build.properties
# sbt.version=1.10.6  →  sbt 1.x
# sbt.version=2.0.0   →  sbt 2.x
```

Key differences are noted throughout this skill with **sbt 2.x** markers.

## Architecture: sbt Runner / sbtn / sbt Server

sbt has three components that work together. Understanding them explains most "sbt is confusing" problems:

| Component | Role | Startup |
|---|---|---|
| **sbt runner** | Shell script. Reads `project/build.properties`, downloads the right sbt version, launches it | Seconds |
| **sbtn** | GraalVM native thin client (~0.07s). Sends commands to server via JSON-RPC | Near-instant |
| **sbt server** | Persistent JVM: Zinc compiler, Coursier resolver, task engine. Accepts commands from sbtn and IDEs via BSP | 24-90s first time |

**Always prefer sbtn.** It talks to the running server — no JVM startup penalty:

```bash
sbt compile    # May start a new JVM. Slow on first invocation.
sbtn compile   # Sends to running server. Near-instant.
```

In sbt 2.x, `sbt` defaults to sbtn. In sbt 1.x, use `sbt --client` or install sbtn separately.

Server lifecycle:
```bash
sbtn shutdown      # Stop the server for this project
sbtn shutdownall   # Stop ALL sbt servers on this machine
sbtn exit          # Disconnect client (server keeps running)
```

## The Critical Rule: Build File Changes Require Reload

The server caches the build definition in memory. When you edit build files, the server doesn't automatically notice — you need to tell it.

**Reload after changing:**
- `build.sbt` — any setting, dependency, or task change
- `project/*.sbt` — plugin additions/removals
- `project/*.scala` — e.g., `Dependencies.scala`
- `project/build.properties` — sbt version itself

```bash
sbtn reload          # Re-reads build definition, keeps JVM warm
```

`reload` is fast — it re-evaluates the build DSL without restarting the JVM. Try it first for every build file change.

When `reload` isn't enough (plugin additions, sbt version changes, or the server gets into a confused state):
```bash
sbtn shutdown        # Kill the server entirely
sbtn compile         # Starts fresh server
```

Auto-reload option — sbt watches build files and reloads automatically:
```scala
Global / onChangedBuildSource := ReloadOnSourceChanges
```

## Metals / IDE Integration (BSP)

When Metals or IntelliJ connects to sbt via BSP, they share the same sbt server JVM. This means:

- `sbtn` from the terminal connects to the **same** server Metals is using
- Editing `build.sbt` in the IDE triggers a BSP notification — the IDE may reload automatically
- If the IDE is stuck, `sbtn reload` from the terminal fixes both
- If that fails, `sbtn shutdown` restarts everything — but the IDE will need to reconnect (a few seconds)

```scala
// Opt specific subprojects out of BSP (useful for large monorepos)
bspEnabled := false
```

## Settings DSL — The Core Operators

| Operator | Meaning | Example |
|---|---|---|
| `:=` | **Replace** entirely | `name := "my-app"` |
| `+=` | **Append** one element | `libraryDependencies += "org" %% "lib" % "1.0"` |
| `++=` | **Concatenate** a sequence | `libraryDependencies ++= Seq(cats, circe)` |
| `~=` | **Transform** existing value | `scalacOptions ~= (_.filterNot(_ == "-Xlint"))` |

The most common mistake with these operators — using `:=` on a Seq-typed key wipes all existing values:

```scala
// Removes ALL default source directories — usually not what you want
Compile / sourceDirectories := Seq(file("custom-src"))

// Adds to existing — preserves defaults
Compile / sourceDirectories += file("custom-src")
```

Use `+=` and `++=` to append. Use `:=` only when you intend to replace.

## Scope System — Three Axes

Every sbt key lives in a three-dimensional space: **subproject × configuration × task**.

```
core / Compile / console / scalacOptions
  │       │        │          │
  │       │        │          └── Task axis (which task's context)
  │       │        └── Configuration: Compile, Test, Runtime
  │       └── Subproject: named project or ThisBuild
  └── Slash syntax
```

**`ThisBuild`** — shared defaults for all subprojects:
```scala
ThisBuild / scalaVersion  := "3.3.3"
ThisBuild / organization  := "com.example"
ThisBuild / version       := "0.1.0-SNAPSHOT"
```

**Inspection commands** — essential for understanding what's happening:
```bash
sbtn "inspect scalacOptions"        # Where does the value come from?
sbtn "inspect tree scalacOptions"   # Full dependency tree with types
sbtn "show scalacOptions"           # Execute and print current value
```

**sbt 2.x change**: Bare settings (not inside `.settings(...)`) are now "common settings" applied to ALL subprojects. In sbt 1.x, they only applied to the root project.

For the full delegation chain, key types (SettingKey vs TaskKey vs InputKey), and custom task definitions, see **references/scope-and-settings.md**.

## Project Structure — What Goes Where

```
my-project/
├── build.sbt                    # Main build definition
├── .sbtopts                     # JVM flags for sbt ITSELF (e.g., -J-Xmx2G)
├── .jvmopts                     # JVM flags for FORKED processes (run, test)
├── project/
│   ├── build.properties         # sbt version: sbt.version=1.10.6
│   ├── plugins.sbt              # sbt plugins
│   └── Dependencies.scala       # Centralized version/deps (convention)
└── src/main/scala/ ...
```

**`.sbtopts` vs `.jvmopts`** — a frequent source of confusion because they control different JVMs:
- `.sbtopts` → sbt's own JVM (the build tool process itself)
- `.jvmopts` → forked JVMs spawned by `run` and `test` tasks

## Incremental Compilation (Zinc)

sbt uses Zinc — only changed files and their dependents get recompiled. Zinc uses **name hashing**: adding a method to class `A` only recompiles files that reference that method's name, not everything depending on `A`.

**Why `sbt clean` fixes mysterious issues**: Branch switches, dependency changes, or compiler plugin updates can corrupt the incremental analysis cache. `clean` deletes all cached state, forcing a full recompilation from scratch.

**Performance tip**: Explicitly annotate return types on public methods — this prevents spurious recompilation when inferred types change unexpectedly.

## Debugging with `last`

When a task fails or behaves unexpectedly, `last` shows the full output that sbt suppresses by default:

```bash
sbtn "last compile"       # Full compiler output from last compile
sbtn "last test"          # Full test failure details
sbtn "last update"        # Dependency resolution details
```

This is the first command to reach for when something goes wrong.

## Continuous Execution with `~`

The `~` prefix watches source files and re-runs the command on every change:

```bash
sbtn "~compile"           # Recompile on every file save
sbtn "~test"              # Re-run all tests on every file save
sbtn "~testQuick"         # Re-run only failed + affected tests
```

Press Enter to stop watching. In sbt 2.x, `testQuick` is cached and incremental — it only re-runs tests affected by code changes.

## Typical Workflow

```bash
# Start the day
sbtn compile                    # First run starts server (slow), after that it's fast

# Development cycle
sbtn "~compile"                 # Continuous compilation
sbtn "~testQuick"               # Continuous testing (only affected tests)

# Edit build.sbt (add a dependency)
sbtn reload                     # Picks up the change
sbtn compile

# Edit project/plugins.sbt (add a plugin)
sbtn shutdown                   # Full restart for plugin changes
sbtn compile

# Something is wrong
sbtn "last compile"             # Full output of last compile
sbtn "inspect tree compile"     # Full task dependency tree
```

## Common Commands

```bash
# Compilation
sbtn compile                    # Compile main sources
sbtn "Test / compile"           # Compile test sources
sbtn clean                      # Delete all build artifacts

# Testing
sbtn test                       # Run all tests
sbtn testFull                   # Uncached full run (sbt 2.x)
sbtn "testOnly com.example.MySpec"   # Specific test class
sbtn "testOnly *Spec"                # Glob pattern

# Running
sbtn run                        # Run main class

# Dependencies
sbtn dependencyTree             # Full dependency graph
sbtn dependencyList             # Resolved list
sbtn evicted                    # Overridden dependencies

# Project navigation (multi-module)
sbtn projects                   # List all subprojects
sbtn "project core"             # Switch to core module
sbtn "core / compile"           # Compile just core

# Interactive shell
sbtn                            # Enter interactive mode
# Inside the shell:
# > ~compile                    Continuous compilation
# > set scalaVersion := "3.3.3" Temporary setting change
# > session save                Persist temp settings to build.sbt
# > reload                      Re-read build definition
# > last compile                Detailed output of last compile
# > plugins                     List enabled auto plugins
# > help compile                Documentation for a task
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `build.sbt` changes not taking effect | Server using cached definition | `sbtn reload` |
| Plugin not loading after `plugins.sbt` edit | Reload may not reinitialize plugins | `sbtn shutdown` then `sbtn compile` |
| `sbtn` says "server not found" | No server running | Run any `sbtn` command (auto-starts) or `sbt --server` |
| `sbtn` hangs / no response | Server in bad state | `sbtn shutdown` then restart |
| Runtime uses old code despite clean compile | Stale class files | `sbtn clean` then `sbtn compile` |
| "server already running" | Another instance holds the lock | `sbtn shutdown` or kill the process |
| Slow first compilation | JVM startup + dependency resolution | Expected. Use sbtn for subsequent runs |
| "Reference to undefined setting" | Missing scope or uninitialized key | Use `inspect` to check scope chain |
| Eviction errors blocking build | Binary incompatible dependency override | `evictionErrorLevel := Level.Info` or fix versions |
| IDE (Metals) is stuck | BSP server confused | `sbtn reload` from terminal, or `sbtn shutdown` |

## JVM Memory

```bash
# .sbtopts — sbt's own JVM
-J-Xmx2G
-J-Xss4M

# .jvmopts — forked test/run JVMs
-Xmx2G
-XX:MetaspaceSize=512M
```

For tests that need isolation from sbt's JVM:
```scala
Test / fork := true                        // Separate JVM for tests
Test / javaOptions ++= Seq("-Xmx2G")       // Memory for test JVM
Test / parallelExecution := false           // Sequential test execution
```

## Related Skills

- **scala-build-tools** — Project setup, build.sbt structure, plugins, packaging, cross-compilation. Use that skill for scaffolding; use this skill for operating sbt day-to-day
- **scala-lang** — Scala language features used in build definitions (given/using, extension methods)
- **scala-code-quality** — scalafmt and scalafix integration with sbt (`sbt scalafmtAll`, `sbt scalafixAll`)

## References

Load these when you need exhaustive details or patterns not shown above:

- **references/scope-and-settings.md** — Scope delegation chain, SettingKey vs TaskKey vs InputKey, `.value` macro internals, sbt 2.x common settings behavior, custom task definitions, `.sbtrc` aliases
- **references/dependency-and-multi-project.md** — Cross-building (%%, CrossVersion strategies), resolvers, eviction and versionScheme, multi-project patterns (dependsOn, aggregate, test-to-compile, projectMatrix), centralized Dependencies.scala, publishing
