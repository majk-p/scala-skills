#!/bin/bash
# Set up linting and formatting for a Scala project
# Usage: scripts/setup-lint.sh [--project-dir .] [--scalafmt-version 3.10.7]

set -e

PROJECT_DIR="."
SCALAFMT_VERSION="3.10.7"
SCALAFIX_VERSION="0.14.5"

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --scalafmt-version) SCALAFMT_VERSION="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Setting up Scala linting in: $PROJECT_DIR"
echo "Scalafmt version: $SCALAFMT_VERSION"
echo "Scalafix version: $SCALAFIX_VERSION"
echo "TODO: Generate .scalafmt.conf, .scalafix.conf, and plugins.sbt entries"
