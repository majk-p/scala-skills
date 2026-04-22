#!/bin/bash
# Create a new Scala project with sbt or scala-cli
# Usage: scripts/new-project.sh --name my-project --tool sbt [--scala 3.3.1]

set -e

TOOL="sbt"
NAME=""
SCALA_VERSION="2.13.12"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --tool) TOOL="$2"; shift 2 ;;
    --scala) SCALA_VERSION="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Usage: scripts/new-project.sh --name <name> [--tool sbt|scala-cli] [--scala <version>]"
  exit 1
fi

echo "Creating Scala project: $NAME (tool=$TOOL, scala=$SCALA_VERSION)"
echo "TODO: Implement project scaffolding"
