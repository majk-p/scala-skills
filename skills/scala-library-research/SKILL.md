---
name: scala-library-research
description: Use this skill when you need to learn and document unfamiliar Scala libraries by researching GitHub repositories and analyzing source code. Covers systematic research methodology, repository structure analysis, code pattern extraction, documentation mining, implementation guidance, testing strategies, and common pitfalls. Trigger when the user mentions learning a library, library internals, API confusion, library integration, or needs to understand an unfamiliar Scala library.
---

# Library Research in Scala

Systematic approach to learning unfamiliar Scala libraries through GitHub repository analysis, source code examination, and implementation guidance.

## When to Use

- Struggling to understand a library's API or usage
- Need to integrate a new library into your project
- Encountering confusion with library documentation
- Need to understand library internals or architecture
- Debugging issues related to a specific library
- Creating implementation guidance for library usage

## Research Workflow

### Phase 1: Initial Web Research

Use `web_fetch` to gather official documentation:
- Library homepage and GitHub repository
- API reference documentation
- Getting started guides
- Migration guides

Extract: required imports, dependencies with versions, key API patterns, common pitfalls, type signatures, integration examples.

### Phase 2: GitHub Repository Discovery

```bash
# Search for the repository
github-com_search_repositories query="library-name scala"

# Assess repository: stars, forks, activity, maintainers, latest release
```

### Phase 3: Repository Structure Analysis

```bash
# Explore the root structure
github-com_get_file_contents owner="org" repo="repo-name" path="/"
```

Analyze structure:
- **Source directories** (`src/`, `lib/`, `main/`) — core implementation
- **Test directories** (`test/`, `tests/`, `spec/`) — usage patterns
- **Documentation** (`docs/`, `guide/`) — guides and explanations
- **Examples** (`examples/`, `samples/`) — working code
- **Build files** (`build.sbt`, `project/plugins.sbt`) — dependencies

### Phase 4: Code Pattern Extraction

```bash
# Search for specific patterns
github-com_search_code query="language:scala repo:org/repo 'def connect'"
```

Focus on: entry points and public API, main interfaces and types, common usage patterns, error handling approaches, configuration patterns.

### Phase 5: Documentation Mining

```bash
github-com_get_file_contents owner="org" repo="repo-name" path="README.md"
github-com_get_file_contents owner="org" repo="repo-name" path="docs/GUIDE.md"
```

### Phase 6: Deep Analysis (Local Clone)

When GitHub tools are insufficient, clone locally:

```bash
scripts/clone-library.sh --repo repo-name --owner org --branch main
```

Use local tools: `read` for source files, `grep` for pattern searching, `glob` for file discovery. Test files are often the best documentation — they show edge cases, intended usage, and implicit assumptions.

## Code Analysis Patterns

### Entry Point Identification
- Main module exports and public API definitions
- Factory methods and constructors
- Initializer functions

### Interface Analysis
- Trait/interface definitions and type signatures
- Parameter types, constraints, and return value structures

### Implementation Patterns
- Dependency injection approaches and state management strategies
- Configuration handling and error handling patterns

### Test Analysis
- Test structure, organization, setup and teardown patterns
- Mocking strategies and usage examples in test cases

## Common Pitfalls

### Skipping Architecture Research

```markdown
Wrong: Find example → Copy/paste → Modify until it works

Correct: Understand architecture → Identify core abstractions → Study examples in context
```

### Relying Only on Documentation

Documentation can be outdated or incomplete. Always verify against source code, test files, and recent issues/PRs.

### Copying Examples Without Context

```scala
// Wrong — copying without understanding
val result = library.someMethod(config).option.build().execute()

// Correct — understand each step
// someMethod: sets up the core operation
// .option: configures optional behavior
// .build: finalizes configuration (immutable)
// .execute: triggers side effect
```

### Ignoring Library Version

Always check the version in build files. Find examples matching that version. Check changelog for breaking changes.

## Implementation Guidance

### Quick Start Template

Minimal working example structure:
1. Exact imports
2. Dependencies with versions
3. Setup code
4. Core operation
5. Expected output

### Code Example Standards

- Complete, runnable code
- Clear comments explaining steps
- Error handling included
- Resource cleanup shown
- Multiple scenarios covered

### Testing Strategies

```scala
// Pattern testing
test("handles valid input") {
  val input = createValidInput()
  val result = Library.process(input)
  assert(result.isSuccess)
}

// Error handling testing
test("returns specific error for condition") {
  val result = Library.riskyOperation()
  assert(result.isLeft)
}
```

### Quality Checklist

Before providing implementation guidance, verify:
- Required imports are exact
- Dependencies have correct versions
- Code examples compile
- Error handling is shown
- Multiple scenarios covered
- Edge cases documented

## Error Handling Patterns

```scala
def handleGitHubAccess[T](owner: String, repo: String)(op: => T): Either[String, T] =
  try Right(op)
  catch {
    case e: java.io.IOException => Left(s"Network error: ${e.getMessage}")
    case e: IllegalArgumentException => Left(s"Repository not found: $owner/$repo")
  }

def withTimeout[T](timeout: Duration)(op: => T): Either[String, T] =
  try {
    val start = System.currentTimeMillis()
    val result = op
    if (System.currentTimeMillis() - start > timeout.toMillis)
      Left("Operation timed out")
    else Right(result)
  } catch {
    case e: Exception => Left(s"Operation failed: ${e.getMessage}")
  }
```

## Output Format

```markdown
## Library: [Name]

### Installation
libraryDependencies += "org" %% "name" % "version"

### Imports
import library.package.api._

### Quick Start
// Complete minimal example

### Common Patterns
1. [Scenario]: [example]

### Error Handling
// Error handling example

### Testing
// Test example

### Best Practices
- [Practice 1]
- [Practice 2]
```

## Related Skills

- **scala-build-tools** — for understanding build configurations and dependencies of target libraries
- **scala-code-quality** — for evaluating library code quality and contributing improvements

## References

Load these when you need detailed methodology or implementation patterns:

- **references/methodology.md** — Complete research methodology: GitHub analysis workflows, code analysis patterns, documentation mining techniques, local clone strategies
- **references/implementation.md** — Implementation guidance: code example templates, testing strategies, documentation writing structure, quality checklist
