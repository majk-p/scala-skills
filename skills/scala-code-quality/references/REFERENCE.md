# Code Quality Tools Reference

Complete reference documentation for Scala code quality tools including Scalafmt, Scalafix, Bloop, Metals, and Codebrag.

## Table of Contents

- [Scalafmt Reference](#scalafmt-reference)
  - [Configuration Syntax](#configuration-syntax)
  - [Formatting Rules](#formatting-rules)
  - [Presets](#presets)
  - [IDE Integration](#ide-integration)
  - [sbt Plugin Reference](#sbt-plugin-reference)
- [Scalafix Reference](#scalafix-reference)
  - [Built-in Rules](#built-in-rules)
  - [Custom Rules](#custom-rules)
  - [Migration Rules](#migration-rules)
  - [Semantic vs Syntactic Rules](#semantic-vs-syntactic-rules)
  - [CLI Reference](#cli-reference)
- [Bloop Reference](#bloop-reference)
  - [Installation](#installation-1)
  - [CLI Commands](#cli-commands)
  - [Build Server Protocol](#build-server-protocol)
  - [IDE Integration](#ide-integration-1)
- [Metals Reference](#metals-reference)
  - [LSP Features](#lsp-features)
  - [Code Actions](#code-actions)
  - [Build Import](#build-import)
  - [Configuration](#configuration)
- [CI/CD Integration](#cicd-integration)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Code Review Automation](#code-review-automation)

---

## Scalafmt Reference

### Configuration Syntax

Scalafmt uses HOCON (Human-Optimized Config Object Notation) for configuration.

```hocon
version = 3.10.7  // Required - formatter version

// Required - Scala dialect for parsing
runner.dialect = scala213  // scala211, scala212, scala213, scala3, sbt0137, sbt1

// File-specific dialect overrides
fileOverride {
  "glob:**/scala3/**" {
    runner.dialect = scala3
  }
  "glob:**/sbt/*.scala" {
    runner.dialect = sbt1
  }
}
```

### Formatting Rules

#### Max Column

```hocon
maxColumn = 100  // Default: 80

// Considerations:
// - 80 fits split laptop screens
// - GitHub mobile shows 80 chars
// - Values > 100 may cause issues with other tools
```

#### Indentation

```hocon
indent.main = 2                    // Primary indentation (default: 2)
indent.callSite = 2                 // Method call arguments (default: 2)
indent.defnSite = 4                 // Method parameters (default: 4)
indent.ctorSite = 4                 // Constructor parameters (default: same as defnSite)
indent.caseSite = 4                  // Case clause patterns (default: 4)
indent.extendSite = 4                // Extends clauses (default: 4)
indent.withSiteRelativeToExtends = 2   // Additional indent for with clauses (default: 0)
indent.commaSiteRelativeToExtends = 4 // Comma-separated parents (default: 2)

// Scala 3 significant indentation
indent.significant = 2  // Default: same as indent.main

// Fewer braces indentation
indent.fewerBraces = never  // never, always, beforeSelect

// Control flow
indent.ctrlSite = 4  // if/while/etc conditions (default: same as callSite)

// Match sites
indent.matchSite = null  // Case clauses (default: null)

// Relative to LHS last line
indent.relativeToLhsLastLine = [match, infix]  // [], [match], [infix], [match, infix]
```

#### Alignment

```hocon
align.preset = more  // none, some, more, most

// None - minimal alignment
align.preset = none

// Some - align case arrows
align.preset = some

// More - align assignments, extends, enums, etc.
align.preset = more

// Most - align everything including for enumerators
align.preset = most

// Custom tokens
align.tokens = [
  { code = "=>", owners = [{ regex = "Case" }] },
  { code = "%", owners = [{ regex = "Term.ApplyInfix" }] },
  { code = "%%", owners = [{ regex = "Term.ApplyInfix" }] }
]

// Strip margin alignment
assumeStandardLibraryStripMargin = true
align.stripMargin = true
```

#### Newlines

```hocon
// Before/after specific tokens
newlines.beforeCurlyLambdaParams = squash  // never, always, squash
newlines.afterCurlyLambdaParams = preserve  // never, always, preserve
newlines.implicitParamListModifierPrefer = before  // before, after
newlines.implicitParamListModifierForce = before  // before, after, never

// Config style formatting
newlines.configStyle.callSite.prefer = true   // prefer config style for calls
newlines.configStyle.defnSite.prefer = true   // prefer config style for definitions

// Avoid in specific contexts
newlines.avoidInResultType = true  // Scala.js preset

// Before keywords
newlines.beforeOpenParenDefnSite = fold  // never, always, unfold, fold

// Between template body and extends
newlines.betweenTemplateDefAndIfTemplate = keep  // keep, unfold
```

#### Dangling Parentheses

```hocon
danglingParentheses.callSite = true   // Hang closing ) for calls (default: true)
danglingParentheses.defnSite = true   // Hang closing ) for definitions (default: true)
danglingParentheses.ctrlSite = true   // Hang closing ) for control (default: true)
danglingParentheses.tupleSite = true  // Hang closing ) for tuples (default: false)

// Exclude specific sites
danglingParentheses.exclude = [
  { class = "Trait" },
  { class = "Class" }
]
```

#### Rewrites

```hocon
// Scala 3 rewrites
rewrite.scala3.convertToNewSyntax = true
rewrite.scala3.removeOptionalBraces = true
rewrite.scala3.removeEndMarkerMax = 0  // Remove end markers with this many lines or fewer

// Import rewrites
rewrite.imports.sort = ascii  // ascii, keep
rewrite.imports.groups = [
  ["java.*"],
  ["javax.*"],
  ["scala.*"],
  ["org.*"],
  ["com.*"],
  ["*"]
]

// Redundant braces
rewrite.redundantBraces.methodBodies = false
rewrite.redundantBraces.generalExpressions = false
rewrite.redundantBraces.stringInterpolation = false
```

#### Vertical Multiline

```hocon
// Format vertical multiline
verticalMultiline.arityThreshold = 2  // Minimum parameters for vertical formatting
verticalMultiline.newlineAfterOpenParen = true
verticalMultiline.newLineBeforeImplicitKW = true
verticalMultiline.newlineAfterImplicitKW = true
verticalMultiline.newlineBeforeImplicitParamList = true
verticalMultiline.newlineAfterImplicitParamList = true

// Exclude definitions
verticalMultiline.excludeDanglingParens = [
  { class = "Trait" },
  { class = "Class" }
]
```

#### Bin Packing

```hocon
binPack.callSite = never  // always, never, keep
binPack.defnSite = never  // always, never, keep
binPack.parentConstructors = false
binPack.literalArgumentLists = true
binPack.literalsIncludeSimpleExpr = true
binPack.literalsMinArgCount = 5
```

#### Docstrings

```hocon
docstrings.style = Asterisk  // Asterisk, Space, AsteriskSpace, keep
docstrings.wrap = false  // Keep docstrings unwrapped
docstrings.blankFirstLine = false
```

#### Opt-in

```hocon
optIn.breakChainOnFirstMethodDot = false
optIn.breaksInsideChains = true
optIn.configStyleArguments = true
optIn.blankLineBeforeDocstring = false
optIn.annotationNewlines = false
```

### Presets

```hocon
// IntelliJ style
preset = IntelliJ

// Scala.js style
preset = Scala.js

// Default with more alignment
preset = defaultWithAlign

// Custom preset
preset = default
align.preset = more
```

### IDE Integration

#### IntelliJ IDEA

- Scala plugin (2019.1+) includes Scalafmt
- Enable format on save: Preferences > Editor > Code Style > Scala
- Choose formatter when prompted

#### VS Code

- Metals extension provides formatting via Scalafmt
- Format on save configured in settings.json:
```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "scalameta.metals"
}
```

#### Vim/Neovim

- Use Metals via coc.nvim or nvim-metals
- Format command: `:MetalsFormat`

#### Emacs

- Use Metals via lsp-mode
- Format function: `lsp-format-buffer`

### sbt Plugin Reference

```scala
// project/plugins.sbt
addSbtPlugin("org.scalameta" % "sbt-scalafmt" % "2.5.4")
```

#### Task Keys

```scala
// Format tasks
scalafmt              // Format main sources
scalafmtAll           // Format all configurations
scalafmtCheck          // Check formatting (fails if unformatted)
scalafmtCheckAll       // Check all configurations
scalafmtSbt            // Format *.sbt and project/*.scala
scalafmtSbtCheck       // Check *.sbt files

// Format specific files
scalafmtOnly <file>...  // Format specified files
```

#### Settings

```scala
// Configuration file location
scalafmtConfig := baseDirectory.value / ".scalafmt.conf"

// Run on compile (discouraged)
scalafmtOnCompile := false

// Filter files
scalafmtFilter := "diff-dirty"  // diff-dirty, diff-ref=<spec>, none

// Error handling
scalafmtDetailedError := true
scalafmtLogOnEachError := true
scalafmtFailOnErrors := true

// Show diffs in check mode
scalafmtPrintDiff := true
```

---

## Scalafix Reference

### Built-in Rules

#### Syntactic Rules

Run without compilation:

**ProcedureSyntax** - Replace deprecated procedure syntax
```bash
sbtn "scalafix ProcedureSyntax"
```

```diff
- def myProcedure {
+ def myProcedure: Unit = {
    println("hello")
  }
```

**DisableSyntax** - Report errors for disabled features
```hocon
rules = [DisableSyntax]

DisableSyntax.noXmlLiterals = true
DisableSyntax.noDefVars = true
DisableSyntax.noTabs = true
```

**RedundantSyntax** - Remove redundant syntax
```bash
sbtn "scalafix RedundantSyntax"
```

```diff
- final object MyObject
+ object MyObject
```

**NoValInForComprehension** - Remove deprecated val in for-comprehension
```bash
sbtn "scalafix NoValInForComprehension"
```

```diff
- for {
-   val x <- xs
+ for {
    x <- xs
  } yield x * 2
```

**LeakingImplicitClassVal** - Add private to implicit class val params
```bash
sbtn "scalafix LeakingImplicitClassVal"
```

**NoAutoTupling** - Add explicit tuples
```bash
sbtn "scalafix NoAutoTupling"
```

```diff
- foo(1, 2)
+ foo((1, 2))
```

#### Semantic Rules

Require SemanticDB compilation:

**RemoveUnused** - Remove unused imports and terms
```bash
sbtn "scalafix RemoveUnused"
```

```diff
- import scala.util.{ Success, Failure }
+ import scala.util.Success
```

```hocon
rules = [RemoveUnused]
RemoveUnused.imports = true  // Remove unused imports
RemoveUnused.privates = true  // Remove unused private members
```

**OrganizeImports** - Sort and group imports
```bash
sbtn "scalafix OrganizeImports"
```

```hocon
rules = [OrganizeImports]

OrganizeImports.removeUnused = true
OrganizeImports.importsOrder = [[java], [scala], [org], [com], [*]]

OrganizeImports.groups = [
  ["javax\\.?\\..*", "scala\\.?\\..*"]
]
```

**ExplicitResultTypes** - Add type annotations to public members
```bash
sbtn "scalafix ExplicitResultTypes"
```

```hocon
rules = [ExplicitResultTypes]

ExplicitResultTypes.fatalWarnings = false
ExplicitResultTypes.skipLocalDefinitions = true
ExplicitResultTypes.skipSimpleNameResolution = true
ExplicitResultTypes.unsafeDeprecation = false
```

```diff
- def add(x: Int, y: Int) = x + y
+ def add(x: Int, y: Int): Int = x + y
```

### Custom Rules

#### Creating Custom Rules

```scala
// build.sbt
ThisBuild / scalafixDependencies ++= Seq(
  "com.example" %% "my-scalafix-rule" % "1.0.0"
)
```

#### Custom Rule Structure

```scala
package fix

import scalafix.v1._
import scala.meta._

class MyRule(implicit index: SemanticdbIndex) extends SemanticRule("MyRule") {
  override def fix(implicit doc: SemanticDocument): Patch = {
    doc.tree.collect {
      case Term.Name(name) if isBadName(name) =>
        Patch.replaceTree(tree, "betterName")
    }.asPatch
  }

  private def isBadName(name: String): Boolean = ???
}
```

#### Rule Configuration

```hocon
rules = [MyRule]

MyRule {
  setting = "value"
  enabled = true
}
```

### Migration Rules

#### Scala 2 to 3 Migration

```hocon
rules = [
  ProcedureSyntax,
  RedundantSyntax,
  NoValInForComprehension
]
```

#### Library Migration

```bash
# Migrate from deprecated library
sbtn "scalafix -r com.example:rule:0.1.0"
```

### Semantic vs Syntactic Rules

**Syntactic Rules:**
- Run on source code without compilation
- Fast but limited analysis
- Examples: ProcedureSyntax, DisableSyntax, RedundantSyntax

**Semantic Rules:**
- Require SemanticDB compilation
- Full type and symbol information
- Examples: RemoveUnused, ExplicitResultTypes, OrganizeImports

### CLI Reference

```bash
# Basic usage
scalafix --rules RemoveUnused src/

# Check mode (read-only)
scalafix --check

# Specific files
scalafix --files src/main/scala/Main.scala

# With configuration
scalafix --config .scalafix.conf

# Syntactic only
scalafix --syntactic

# Verbose output
scalafix --verbose

# Multiple rules
scalafix --rules RemoveUnused --rules OrganizeImports
```

---

## Bloop Reference

### Installation

```bash
# Install via Coursier
cs install bloop

# Verify installation
bloop --version
```

### CLI Commands

```bash
# Compile
bloop compile <project>

# Compile all
bloop compile all

# Test
bloop test <project>

# Run
bloop run <project>

# Clean
bloop clean <project>

# Watch mode
bloop compile <project> --watch

# List projects
bloop projects

# Show project info
bloop configure <project>
```

### Build Server Protocol

Bloop implements the Build Server Protocol (BSP):

```bash
# Start BSP server
bloop bsp

# Use with client (e.g., Metals)
# Metals connects automatically
```

BSP capabilities:
- Compile
- Test
- Run
- Dependency sources
- Dependency resources
- Diagnostics

### IDE Integration

#### Metals

Metals uses Bloop by default:
- Fast compilation via BSP
- Compile deduplication
- Cross-build support

#### IntelliJ IDEA

- Bloop plugin available
- Import build via "Import Bloop Project"

#### VS Code

- Metals extension connects to Bloop
- Automatic BSP connection

---

## Metals Reference

### LSP Features

#### Diagnostics

- Syntax errors (instant)
- Type errors (on save)
- Compiler warnings

#### Navigation

- Goto Definition (F12)
- Goto Type Definition (Shift+F12)
- Goto Implementation (Cmd+F12)
- Find References (Shift+F12)

#### Completions

- Auto-import insertion
- Override methods
- Implement interface
- Exhaustive match
- String interpolator

#### Hover

- Expression type
- Symbol signature
- Documentation

#### Code Actions

- Quick fixes
- Refactoring suggestions
- Import insertion
- Type annotation

### Code Actions

```hocon
// Metals configuration
"metals.showImplicitArguments": true
"metals.showInferredType": true
"metals.superMethodLensesEnabled": true
```

### Build Import

Metals imports builds via BSP:

**sbt:**
- Requires Bloop installation
- Auto-import on project open

**Gradle:**
- Use Bloop Gradle plugin

**Maven:**
- Use Bloop Maven plugin

**Mill:**
- Use Bloop Mill module

### Configuration

Metals properties (`.metals/metals.properties`):

```properties
# Custom Scala version
metals.java-home = /path/to/java
metals.scalafmt-config-path = .scalafmt.conf
metals.scalafix-config-path = .scalafix.conf

# Bloop settings
metals.bloopVersion = 1.5.18

# Formatting
metals.scalafmt-on-save = true

# Code actions
metals.showImplicitArguments = true
metals.showInferredType = true
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Code Quality

on:
  pull_request:
    branches: [main, develop]

jobs:
  format:
    name: Check Formatting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21

      - name: Cache SBT
        uses: actions/cache@v4
        with:
          path: |
            ~/.sbt
            ~/.ivy2/cache
            ~/.coursier/cache
          key: ${{ runner.os }}-sbt-${{ hashFiles('**/*.sbt') }}-${{ hashFiles('**/project/build.properties') }}

      - name: Check Scalafmt
        run: sbtn scalafmtCheckAll

  lint:
    name: Run Scalafix
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21

      - name: Cache SBT
        uses: actions/cache@v4
        with:
          path: |
            ~/.sbt
            ~/.ivy2/cache
            ~/.coursier/cache
          key: ${{ runner.os }}-sbt-${{ hashFiles('**/*.sbt') }}-${{ hashFiles('**/project/build.properties') }}

      - name: Run Scalafix
        run: sbtn "scalafixAll --check"
```

### GitLab CI

```yaml
stages:
  - quality

format:
  stage: quality
  image: hseeberger/scala-sbt:latest
  script:
    - sbtn scalafmtCheckAll

lint:
  stage: quality
  image: hseeberger/scala-sbt:latest
  script:
    - sbtn "scalafixAll --check"
```

### Pre-commit Hooks

#### Simple Git Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "Running Scalafmt..."
sbtn scalafmtCheckAll || {
  echo "❌ Code is not formatted"
  echo "Run: sbtn scalafmtAll"
  exit 1
}

echo "Running Scalafix..."
sbtn "scalafixAll --check" || {
  echo "❌ Scalafix found issues"
  echo "Run: sbtn scalafixAll"
  exit 1
}

echo "✅ All quality checks passed"
```

#### Pre-commit Framework

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: scalafmt
        name: Scalafmt Check
        entry: sbtn scalafmtCheckAll
        language: system
        pass_filenames: false

      - id: scalafix
        name: Scalafix Check
        entry: sbtn "scalafixAll --check"
        language: system
        pass_filenames: false

      - id: compile
        name: Compile Check
        entry: sbtn compile
        language: system
        pass_filenames: false
```

---

## Code Review Automation

### Codebrag

Codebrag provides daily automated code review.

#### Installation

```bash
# Download and run
java -jar codebrag.jar

# Configure via local.conf
```

#### Configuration

```hocon
# local.conf
codebrag {
  repository {
    dir = "/path/to/repo"
  }

  review {
    startHour = 9
    endHour = 17
    timezone = "UTC"
  }

  notifications {
    enabled = true
    email = "team@example.com"
  }
}
```

#### Features

- Daily email digests of changes
- Inline commenting
- Approval workflows
- Integration with Git hooks

---

## Best Practices

### Scalafmt Best Practices

1. **Version Pinning**: Always specify `version` in `.scalafmt.conf`
2. **Dialect Matching**: Set `runner.dialect` to match your Scala version
3. **Team Consistency**: Share `.scalafmt.conf` across projects
4. **Column Width**: Use sensible `maxColumn` (80-100)
5. **Progressive Disclosure**: Start with `preset`, then customize

### Scalafix Best Practices

1. **Enable SemanticDB**: Required for powerful rules
2. **Start Small**: Run one rule at a time
3. **Check Mode**: Use `--check` in CI
4. **Custom Rules**: Create rules for project-specific patterns
5. **Migration**: Use for version upgrades

### Bloop Best Practices

1. **Watch Mode**: Use `--watch` for rapid feedback
2. **Cache Management**: Cache compilation artifacts
3. **Cross-Build**: Leverage concurrent compilation
4. **IDE Integration**: Use with Metals for best experience

### Metals Best Practices

1. **Regular Updates**: Keep Metals server updated
2. **Build Import**: Ensure proper BSP connection
3. **Shortcuts**: Learn keyboard shortcuts for efficiency
4. **Code Actions**: Leverage Metals extensions for productivity

---

## Troubleshooting

### Scalafmt

**Issue**: Configuration not recognized
- Ensure `.scalafmt.conf` is in project root
- Check `version` is specified
- Verify HOCON syntax

**Issue**: Format differs between editors
- Ensure same `version` everywhere
- Check for editor-specific overrides

### Scalafix

**Issue**: Semantic rule fails
- Enable SemanticDB in build
- Ensure sources are compiled first
- Check `scalacOptions` for `-Yrangepos`

**Issue**: Rule not found
- Check `scalafixDependencies` in build.sbt
- Verify rule name spelling

### Bloop

**Issue**: Bloop not starting
- Check Java version (LTS recommended)
- Verify installation via `bloop --version`

**Issue**: Slow compilation
- Check for stale caches
- Verify JVM memory settings

### Metals

**Issue**: Import build failing
- Ensure Bloop is installed
- Check build tool version compatibility
- Verify `.metals/` directory

**Issue**: Slow completions
- Ensure compilation succeeded
- Check for large projects (consider workspace configuration)

---

## Version Information

Current recommended versions (February 2026):

- **Scalafmt**: 3.10.7
- **Scalafix**: 0.14.5
- **Bloop**: 1.5.18
- **Metals**: 1.6.5

Always pin versions in configuration files for reproducibility.
