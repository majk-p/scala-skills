---
name: scala-code-quality
description: Use this skill when improving code quality, formatting, linting, or refactoring Scala code. This includes using scalafmt for code formatting, scalafix for refactoring and linting, bloop for fast compilation, metals for IDE features, and codebrag for automated code reviews. Trigger when the user mentions code formatting, linting, refactoring, code quality, or needs to improve codebase.
---

# Code Quality Tools in Scala

Scala provides a rich ecosystem of code quality tools for formatting, linting, refactoring, and development experience. This skill covers Scalafmt (code formatter), Scalafix (refactoring and linting), Bloop (fast build server), Metals (language server), and Codebrag (code review automation).

## Quick Start

### Scalafmt

Create `.scalafmt.conf` in project root:

```hocon
version = "3.10.7" // check for latest
runner.dialect = scala213
maxColumn = 100
```

Run from sbt:
```bash
sbt scalafmtAll        # Format all sources
sbt scalafmtCheckAll   # Check formatting
```

### Scalafix

Add to `project/plugins.sbt`:
```scala
addSbtPlugin("ch.epfl.scala" % "sbt-scalafix" % "0.14.5")
```

Enable SemanticDB in `build.sbt`:
```scala
inThisBuild(
  List(
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision
  )
)
```

Run Scalafix:
```bash
sbt "scalafix RemoveUnused"
```

### Bloop

```bash
cs install bloop       # Install Bloop
bloop install          # Export sbt project
bloop compile project  # Compile with Bloop
bloop test project     # Test with Bloop
```

### Metals

Install Metals via your editor extension (VS Code, Vim, Emacs, etc.). Metals uses `.scalafmt.conf` for formatting and `.bloop/` for fast compilation.

## Scalafmt Core Patterns

### Configuration

```hocon
version = "3.10.7" // check for latest
runner.dialect = scala213  // scala211, scala212, scala3, sbt1

// Column settings
maxColumn = 100

// Indentation
indent.main = 2
indent.callSite = 2
indent.defnSite = 4

// Alignment
align.preset = more  // none, some, more, most
```

### Format Commands

```bash
sbt scalafmt              # Format main sources
sbt Test/scalafmt         # Format test sources
sbt scalafmtAll           # Format all (main + test)
sbt scalafmtCheckAll      # Check formatting (fails if unformatted)
sbt "scalafmtOnly src/main/scala/Main.scala"  # Format specific file
```

### Presets

```hocon
preset = IntelliJ             // IntelliJ style
preset = defaultWithAlign     // Enable more alignment
```

## Scalafix Core Patterns

### Built-in Rules

```bash
sbt "scalafix ProcedureSyntax"     # Remove deprecated procedure syntax
sbt "scalafix RemoveUnused"        # Remove unused imports and terms
sbt "scalafix OrganizeImports"     # Organize imports
sbt "scalafix ExplicitResultTypes" # Add explicit result types
sbt "scalafix RedundantSyntax"     # Remove redundant syntax
sbt "scalafix DisableSyntax"       # Disable syntax features
```

### Configuration File

Create `.scalafix.conf`:
```hocon
rules = [
  ProcedureSyntax,
  RemoveUnused,
  OrganizeImports,
  ExplicitResultTypes
]

ExplicitResultTypes {
  fatalWarnings = false
}
```

### Check in CI

```bash
sbt "scalafixAll --check"  # Fail build if files need fixing
```

### Custom Rules

```scala
ThisBuild / scalafixDependencies ++= Seq(
  "com.example" %% "custom-scalafix-rule" % "1.0.0"
)
```

## Bloop Core Patterns

### Fast Compilation Workflow

Bloop provides compile deduplication across clients, concurrent compilation isolation, and independent output directories.

```bash
bloop compile project --watch   # Watch mode for rapid feedback
bloop test project --watch      # Run tests in watch mode
```

### Bloop with Metals

Metals automatically uses Bloop for fast compilation, incremental compilation, and cross-build support.

## Metals Core Patterns

### Key Features

- **Goto Definition** — Navigate to symbol definitions in project and dependencies
- **Code Completion** — Auto-import insertion, override implementation, exhaustive match generation
- **Hover** — Show expression type and symbol signature with documentation
- **Find References** — Find all usages of a symbol including implicits and inferred calls

### Editor Support

VS Code (Scala Metals extension), IntelliJ IDEA, Vim/Neovim (coc.nvim or nvim-metals), Emacs (lsp-mode), Sublime Text (LSP package).

## Common Patterns

### CI/CD Integration

```yaml
name: Code Quality
on:
  pull_request:
  push:
    branches: [main]

jobs:
  format-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          distribution: temurin
          java-version: 17
      - name: Check formatting
        run: sbt scalafmtCheckAll

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          distribution: temurin
          java-version: 17
      - name: Run Scalafix
        run: sbt "scalafixAll --check"
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: scalafmt
        name: Check Scala formatting
        entry: sbt scalafmtCheckAll
        language: system
        pass_filenames: false

      - id: scalafix
        name: Run Scalafix
        entry: sbt "scalafixAll --check"
        language: system
        pass_filenames: false
```

### Automated Code Reviews

Codebrag provides daily code review emails:

```bash
java -jar codebrag.jar
# Configure via local.conf: Git repository settings, notification settings, review assignment rules
```

## Dependencies

```scala
// project/plugins.sbt
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.4") // check for latest
addSbtPlugin("ch.epfl.scala" % "sbt-scalafix" % "0.14.5") // check for latest

// build.sbt — enable SemanticDB for Scalafix
inThisBuild(
  List(
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision
  )
)

scalacOptions ++= {
  if (scalaVersion.value.startsWith("2.12"))
    Seq("-Ywarn-unused-import")
  else
    Seq("-Wunused:imports")
}
```

```bash
# Bloop — install via Coursier
cs install bloop
```

## Related Skills

- **scala-build-tools** — for sbt configuration and build setup that integrates quality tools
- **scala-lang** — for Scala language patterns that affect code quality decisions

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/REFERENCE.md** — Complete Scalafmt configuration reference, Scalafix rule documentation and patterns, Bloop CLI and BSP protocol reference, Metals LSP features and editor integration, CI/CD integration patterns, pre-commit hook configurations, Codebrag setup
