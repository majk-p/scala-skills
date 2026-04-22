---
name: library-learning-implementation
description: Implementation guidance for integrating unfamiliar libraries, including code examples, testing strategies, best practices, and common pitfalls. Use when you need to implement library usage, write tests, or create integration guides.
license: MIT
compatibility: Works with any programming language and build system
metadata:
  author: opencode-agents
  version: "1.0"
---

# Library Learning - Implementation Guidance

This skill provides practical implementation guidance for integrating unfamiliar libraries, including code examples, testing strategies, and documentation writing.

## Activation Triggers

Activate when:
- You need to implement library integration
- Writing tests for library usage
- Creating integration guides or documentation
- Troubleshooting implementation issues
- Optimizing library usage

## Implementation Guidance Structure

### 1. Quick Start Example
Minimal working example with exact imports, dependencies, setup code, and expected output.

### 2. Core Usage Patterns
Common implementation scenarios: configuration, basic operations, error handling, resource cleanup, workflows.

### 3. Integration Examples
Real-world scenarios: application-specific usage, integration with existing code, performance-critical paths.

### 4. Testing Strategies
Unit testing approaches, integration testing patterns, mocking strategies, test utilities.

## Code Example Guidelines

### Quality Standards
- Complete, runnable code
- Clear comments explaining steps
- Error handling included
- Resource cleanup shown
- Multiple scenarios covered

### Example Templates

#### Basic Usage
```scala
import library.package.api._

val config = LibraryConfig.builder().withOption("value").build()
val result = Library.method(config)
```

#### Error Handling
```scala
import library.package.api._

Library.method(config) match {
  case Success(result) => 
  case Failure(error) => error match {
    case ConfigError(msg) => log(msg)
    case ValidationError(msg) => validate()
    case _ => recover()
  }
}
```

#### Resource Management
```scala
import library.package.api._

Resource.use { resource =>
  resource.performOperation()
}
```

## Testing Strategies

### Test Organization
- Separate unit and integration tests
- Clear test names explaining scenarios
- Setup/teardown in beforeEach/afterEach
- Reusable test utilities

### Test Patterns

#### Pattern Testing
```scala
test("handles valid input") {
  val input = createValidInput()
  val result = Library.process(input)
  assert(result.isSuccess)
}
```

#### Error Handling Testing
```scala
test("returns specific error for condition") {
  val result = Library.riskyOperation()
  assert(result match {
    case Left(_: SpecificError) => true
    case _ => false
  })
}
```

## Common Pitfalls

1. **Over-reliance on Quick Start**: Study full test suite and documentation
2. **Ignoring Version Compatibility**: Always check version in build files
3. **Skipping Error Handling**: Include error scenarios in examples
4. **Not Understanding Dependencies**: List all dependencies with versions
5. **Performance Oversights**: Document performance characteristics

## Documentation Writing

### Structure
1. Overview: What the library does
2. Installation: Dependencies and setup
3. Quick Start: Minimal example
4. Core Concepts: Key abstractions
5. API Reference: Main functions/types
6. Examples: Practical use cases
7. Best Practices: Common patterns
8. Troubleshooting: Common issues

### Best Practices
- Use clear, concise language
- Provide complete examples
- Explain "why" not just "how"
- Include error scenarios
- Reference test files
- Update with version changes

## Quality Checklist

Before providing implementation guidance, verify:
- ✅ Required imports are exact
- ✅ Dependencies have correct versions
- ✅ Code examples compile
- ✅ Error handling is shown
- ✅ Multiple scenarios covered
- ✅ Edge cases documented
- ✅ Test patterns included

## Output Format

```markdown
## Library: [Name]

### Installation
\`\`\`sbt
libraryDependencies += "org" %% "name" % "version"
\`\`\`

### Imports
\`\`\`scala
import library.package.api._
\`\`\`

### Quick Start
\`\`\`scala
// Complete example
\`\`\`

### Common Patterns
1. [Scenario]: [example]
2. [Scenario]: [example]

### Error Handling
\`\`\`scala
// Error handling example
\`\`\`

### Testing
\`\`\`scala
// Test example
\`\`\`

### Best Practices
- [Practice 1]
- [Practice 2]
```
