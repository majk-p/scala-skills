#!/usr/bin/env bash
# Scaffold a new Akka project with sbt
# Usage: ./new-akka-project.sh <project-name> [scala-version]

set -euo pipefail

PROJECT_NAME="${1:?Usage: new-akka-project.sh <project-name> [scala-version]}"
SCALA_VERSION="${2:-2.13.14}"

mkdir -p "$PROJECT_NAME/src/main/scala/$PROJECT_NAME"
mkdir -p "$PROJECT_NAME/src/main/resources"
mkdir -p "$PROJECT_NAME/src/test/scala/$PROJECT_NAME"

cat > "$PROJECT_NAME/build.sbt" <<EOF
name := "$PROJECT_NAME"
version := "0.1.0"
scalaVersion := "$SCALA_VERSION"

// check for latest version
libraryDependencies += "com.typesafe.akka" %% "akka-actor-typed" % "2.10.+"
libraryDependencies += "com.typesafe.akka" %% "akka-actor-testkit-typed" % "2.10.+" % Test
libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.+" % Test
EOF

cat > "$PROJECT_NAME/src/main/scala/$PROJECT_NAME/Main.scala" <<EOF
import akka.actor.typed.{ActorSystem, Behavior}
import akka.actor.typed.scaladsl.Behaviors

object Main extends App {
  val rootBehavior: Behavior[Nothing] = Behaviors.setup[Nothing] { context =>
    context.log.info("$PROJECT_NAME started")
    Behaviors.empty
  }

  val system = ActorSystem[Nothing](rootBehavior, "$PROJECT_NAME")
}
EOF

cat > "$PROJECT_NAME/src/main/resources/application.conf" <<EOF
akka {
  loglevel = INFO
  actor {
    provider = "local"
  }
}
EOF

echo "Created Akka project: $PROJECT_NAME"
echo "  cd $PROJECT_NAME && sbt run"
