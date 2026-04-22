---
name: library-learning-methodology
description: Systematic research methodology for learning unfamiliar libraries, including GitHub repository analysis, documentation extraction, and code analysis patterns. Use when you need to understand library internals, architecture, or API structure.
license: MIT
compatibility: Requires access to GitHub MCP, web_fetch, and ability to clone repositories
metadata:
  author: opencode-agents
  version: "1.0"
---

# Library Learning - Research Methodology

This skill provides systematic techniques for researching unfamiliar libraries through GitHub repository analysis, documentation extraction, and code pattern identification.

## Activation Triggers

Activate when:
- You need to understand library internals or architecture
- Official documentation is unclear or incomplete
- You're analyzing a new library for integration
- You need to map API structure and dependencies
- You're debugging complex library usage issues

## Research Workflow

### Phase 1: Initial Web Research (Always Start Here)

Use `web_fetch` to gather official documentation:
- Library homepage and GitHub repository
- API reference documentation
- Getting started guides
- Migration guides

Extract: required imports, dependencies with versions, key API patterns, common pitfalls, type signatures, integration examples.

### Phase 2: GitHub Repository Discovery

Search for official repository:
```bash
github-com_search_repositories query="library-name scala"
github-com_list_repositories owner="organization-name"
```

Assess repository:
- Stars, forks, and activity levels
- Maintainers and contributors
- Latest release version
- Open issues and PRs

### Phase 3: Repository Structure Analysis

```bash
github-com_get_file_contents owner="org" repo="repo-name" path="/"
```

Analyze structure:
- **Source directories** (`src/`, `lib/`, `main/`)
- **Test directories** (`test/`, `tests/`, `spec/`)
- **Documentation** (`docs/`, `guide/`)
- **Examples** (`examples/`, `samples/`)
- **Build files** (`build.sbt`, `pom.xml`, `Cargo.toml`, `package.json`)

### Phase 4: Code Pattern Extraction

Search for specific patterns:
```bash
github-com_search_code query="language:scala AND org:org-name AND repo:repo-name AND 'def connect'"
```

Focus on:
- Entry points and public API
- Main interfaces and types
- Common usage patterns
- Error handling approaches
- Configuration patterns

### Phase 5: Documentation Mining

```bash
github-com_get_file_contents owner="org" repo="repo-name" path="README.md"
github-com_get_file_contents owner="org" repo="repo-name" path="docs/GUIDE.md"
```

Extract:
- Core concepts and principles
- Architecture and design patterns
- Configuration options
- Performance considerations
- Edge cases and limitations

## Code Analysis Patterns

### 1. Entry Point Identification
- Main module exports
- Public API definitions
- Factory methods and constructors
- Initializer functions

### 2. Interface Analysis
- Trait/interface definitions
- Type signatures
- Parameter types and constraints
- Return value structures

### 3. Implementation Patterns
- Dependency injection approaches
- State management strategies
- Configuration handling
- Error handling patterns

### 4. Test Analysis
- Test structure and organization
- Setup and teardown patterns
- Mocking strategies
- Usage examples in test cases

### 5. Documentation Patterns
- README structure
- API documentation format
- Example code quality
- Migration guides

## Deep Analysis (Local Clone)

When GitHub tools insufficient, clone locally:
```bash
mkdir -p tmp-library-clone
echo "tmp-library-clone/" >> .gitignore
git clone https://github.com/org/repo.git tmp-library-clone/repo-name
```

Use local tools:
- `read` for source files
- `grep` for pattern searching
- `glob` for file discovery
- Test files for usage patterns

## Documentation Template

After research, provide:
- **Repository**: org/repo
- **Latest version**: version number
- **Dependencies**: with exact versions
- **Key imports**: exact statements
- **Core concepts**: main abstractions
- **API patterns**: common usage
- **Pitfalls**: common mistakes

## Common Patterns to Document

### Import Patterns
- Required imports for basic usage
- Optional imports for advanced features
- Implicit imports and implicits

### Dependency Patterns
- Core library dependencies
- Transitive dependencies
- Version compatibility requirements

### Configuration Patterns
- Builder patterns
- Config objects
- Environment variables
- File-based configuration

### Error Handling Patterns
- Error types and exceptions
- Error recovery strategies
- Validation approaches
- Logging patterns
