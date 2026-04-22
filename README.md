# Scala Skills

Experimental, personal collection of Scala skills for AI coding agents.

- **Very opinionated** - braceful Scala syntax only (`-no-indent`), functional programming, mostly typelevel ecosystem
- **Unstable** - prone to breaking changes without notice
- **Use at your own risk**

## Install

Uses the open [agent skills](https://agentskills.io) standard. Works with [OpenCode](https://opencode.ai), [Claude Code](https://code.claude.com), [Cursor](https://cursor.com), [Codex](https://developers.openai.com/codex), and [40+ other agents](https://github.com/vercel-labs/skills).

```bash
# Install all skills
npx skills add https://github.com/majk-p/scala-skills.git

# Install specific skills
npx skills add https://github.com/majk-p/scala-skills.git --skill scala-lang --skill scala-database

# List available skills without installing
npx skills add https://github.com/majk-p/scala-skills.git --list
```

See [vercel-labs/skills](https://github.com/vercel-labs/skills) for the full CLI reference.


## Scope

**Language & Build** - scala-lang (Scala 3 features, braceful syntax), scala-build-tools (sbt, scala-cli), scala-sbt (advanced sbt), scala-code-quality (scalafmt, scalafix)

**Functional Programming** - scala-type-classes (cats type classes, derivation, laws), scala-fp-patterns (tagless final, state management, Iron refinements), scala-async-effects (cats-effect, ZIO), scala-validation (Iron constraints)

**Data & Streaming** - scala-database (doobie, Skunk), scala-streaming (fs2), scala-data-processing (os-lib, subprocess, web scraping), scala-messaging (Kafka, ElasticMQ, Pulsar)

**Web** - scala-web-frameworks (Play, Tapir, ZIO-HTTP), scala-http-clients (sttp), scala-play (Play deep dive), scala-json-circe (circe JSON)

**Testing** - scala-testing (framework comparison: specs2, MUnit, Weaver), scala-testing-specs2 (BDD with specs2), scala-testing-munit (MUnit), scala-testing-weaver (Weaver, effect-native), scala-testing-property (ScalaCheck, Discipline)

**Other** - scala-akka (Akka/Pekko actors), scala-dependency-injection (Macwire, Guice), scala-parsing (FastParse), scala-code-generation (magnolia, scalameta, macros), scala-library-research (learning unfamiliar libraries)
