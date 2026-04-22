#!/usr/bin/env bash
# Generate a new Tapir project using the adopt-tapir API.
# https://adopt-tapir.softwaremill.com/
#
# USAGE MODES:
#
# 1. Guided mode (no flags) — prompts for each option:
#    ./new-tapir-project.sh
#
# 2. Flag mode — pass all options via flags:
#    ./new-tapir-project.sh --name my-app --group com.example \
#      --stack IOStack --impl Http4s --json Circe \
#      --scala Scala3 --builder Sbt --docs --metrics
#
# 3. Raw JSON mode — pass an arbitrary JSON payload directly.
#    Useful when the API has changed and flag values are outdated:
#    ./new-tapir-project.sh --raw '{"projectName":"my-app","groupId":"com.example",...}'
#
# NOTE: The adopt-tapir form fields and valid values may change over time.
# If flag mode fails, use --raw with a payload you construct after inspecting
# the form at https://adopt-tapir.softwaremill.com/ or the API source at
# https://github.com/softwaremill/adopt-tapir

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_URL="https://adopt-tapir.softwaremill.com/api/v1/starter.zip"

# ── Valid values (as of tapir 1.x — may drift, use --raw if these fail) ──

VALID_STACKS="FutureStack IOStack ZIOStack OxStack"
VALID_IMPLS="Netty Http4s ZIOHttp VertX Pekko"
VALID_JSON="No Circe UPickle Jsoniter ZIOJson"
VALID_SCALA="Scala2 Scala3"
VALID_BUILDER="Sbt ScalaCli"

# Stack → valid implementations
IMPL_FUTURE="Netty VertX Pekko"
IMPL_IO="Netty VertX Http4s"
IMPL_ZIO="Netty VertX Http4s ZIOHttp"
IMPL_OX="Netty"

# ── Defaults ──

PROJECT_NAME=""
GROUP_ID="com.example"
STACK=""
IMPLEMENTATION=""
JSON=""
SCALA_VERSION="Scala3"
BUILDER="Sbt"
DOCS=false
METRICS=false
RAW_JSON=""
OUTPUT_DIR=""

# ── Helpers ──

contains() {
  local item="$1"
  local list="$2"
  [[ " $list " == *" $item "* ]]
}

get_valid_impls() {
  case "$1" in
    FutureStack) echo "$IMPL_FUTURE" ;;
    IOStack)     echo "$IMPL_FUTURE" ;;
    ZIOStack)    echo "$IMPL_ZIO" ;;
    OxStack)     echo "$IMPL_OX" ;;
    *)           echo "" ;;
  esac
}

prompt_choice() {
  local prompt="$1"
  local valid="$2"
  local default="$3"
  local result=""

  while true; do
    echo -e "${BLUE}$prompt${NC}"
    echo "  Options: $valid"
    [[ -n "$default" ]] && echo "  Default: $default"
    read -r -p "> " result
    result="${result:-$default}"

    if contains "$result" "$valid"; then
      echo "$result"
      return 0
    else
      echo -e "${RED}Invalid choice '$result'. Pick from: $valid${NC}"
    fi
  done
}

prompt_string() {
  local prompt="$1"
  local default="$2"
  local result=""

  echo -e "${BLUE}$prompt${NC}"
  [[ -n "$default" ]] && echo "  Default: $default"
  read -r -p "> " result
  echo "${result:-$default}"
}

# ── Parse arguments ──

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       PROJECT_NAME="$2";    shift 2 ;;
    --group)      GROUP_ID="$2";        shift 2 ;;
    --stack)      STACK="$2";           shift 2 ;;
    --impl)       IMPLEMENTATION="$2";  shift 2 ;;
    --json)       JSON="$2";            shift 2 ;;
    --scala)      SCALA_VERSION="$2";   shift 2 ;;
    --builder)    BUILDER="$2";         shift 2 ;;
    --docs)       DOCS=true;            shift ;;
    --no-docs)    DOCS=false;           shift ;;
    --metrics)    METRICS=true;         shift ;;
    --no-metrics) METRICS=false;        shift ;;
    --output)     OUTPUT_DIR="$2";      shift 2 ;;
    --raw)        RAW_JSON="$2";        shift 2 ;;
    -h|--help)
      echo "Usage:"
      echo "  $0                                           # Guided mode"
      echo "  $0 --name APP --stack S --impl I [options]   # Flag mode"
      echo "  $0 --raw '{...json...}'                      # Raw JSON mode"
      echo ""
      echo "Flags:"
      echo "  --name NAME       Project name"
      echo "  --group GROUP     Group ID (default: com.example)"
      echo "  --stack STACK     FutureStack|IOStack|ZIOStack|OxStack"
      echo "  --impl IMPL       Netty|Http4s|ZIOHttp|VertX|Pekko (must match stack)"
      echo "  --json LIB        No|Circe|UPickle|Jsoniter|ZIOJson"
      echo "  --scala VER       Scala2|Scala3 (default: Scala3)"
      echo "  --builder B       Sbt|ScalaCli (default: Sbt)"
      echo "  --docs            Include Swagger UI documentation"
      echo "  --metrics         Include Prometheus metrics"
      echo "  --output DIR      Output directory (default: project name)"
      echo "  --raw JSON        Send arbitrary JSON payload directly"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      exit 1
      ;;
  esac
done

# ── Raw JSON mode ──

if [[ -n "$RAW_JSON" ]]; then
  echo -e "${BLUE}=== Raw JSON mode — sending payload as-is ===${NC}"
  echo "Payload: $RAW_JSON"
  echo ""

  ZIP_NAME="tapir-project-$$.zip"
  OUTPUT_DIR="${OUTPUT_DIR:-tapir-project}"

  echo -e "${GREEN}Requesting project from adopt-tapir...${NC}"
  HTTP_CODE=$(curl -s -o "$ZIP_NAME" -w "%{http_code}" \
    -X POST "$API_URL" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/zip' \
    -d "$RAW_JSON")

  if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}API returned HTTP $HTTP_CODE${NC}" >&2
    echo -e "${YELLOW}The payload may be invalid or the API may have changed.${NC}" >&2
    echo -e "${YELLOW}Inspect the form at https://adopt-tapir.softwaremill.com/${NC}" >&2
    echo -e "${YELLOW}or the API source at https://github.com/softwaremill/adopt-tapir${NC}" >&2
    rm -f "$ZIP_NAME"
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"
  unzip -q -o "$ZIP_NAME" -d "$OUTPUT_DIR"
  rm -f "$ZIP_NAME"

  echo -e "${GREEN}Project created in $OUTPUT_DIR/${NC}"
  exit 0
fi

# ── Guided mode (when required flags are missing) ──

if [[ -z "$PROJECT_NAME" ]]; then
  echo -e "${BLUE}=== Adopt Tapir — Project Generator ===${NC}"
  echo -e "${BLUE}https://adopt-tapir.softwaremill.com/${NC}"
  echo ""

  PROJECT_NAME=$(prompt_string "Project name?" "my-tapir-app")
  GROUP_ID=$(prompt_string "Group ID?" "com.example")
  STACK=$(prompt_choice "Effect stack?" "$VALID_STACKS" "IOStack")

  VALID_IMPLS_FOR_STACK=$(get_valid_impls "$STACK")
  IMPLEMENTATION=$(prompt_choice "Server implementation?" "$VALID_IMPLS_FOR_STACK" "")

  JSON=$(prompt_choice "JSON library?" "$VALID_JSON" "Circe")
  SCALA_VERSION=$(prompt_choice "Scala version?" "$VALID_SCALA" "Scala3")
  BUILDER=$(prompt_choice "Build tool?" "$VALID_BUILDER" "Sbt")

  read -r -p "$(echo -e ${BLUE}'Include Swagger UI docs? (y/n) '${NC})" docs_answer
  [[ "${docs_answer,,}" == "y" ]] && DOCS=true || DOCS=false

  read -r -p "$(echo -e ${BLUE}'Include Prometheus metrics? (y/n) '${NC})" metrics_answer
  [[ "${metrics_answer,,}" == "y" ]] && METRICS=true || METRICS=false
fi

# ── Validate ──

errors=0

if [[ -z "$PROJECT_NAME" ]]; then
  echo -e "${RED}Error: --name is required${NC}" >&2; errors=$((errors + 1))
fi

if [[ -n "$STACK" ]] && ! contains "$STACK" "$VALID_STACKS"; then
  echo -e "${RED}Error: Invalid stack '$STACK'. Valid: $VALID_STACKS${NC}" >&2
  echo -e "${YELLOW}The API may have added new options. Use --raw to bypass validation.${NC}" >&2
  errors=$((errors + 1))
fi

if [[ -n "$STACK" ]] && [[ -n "$IMPLEMENTATION" ]]; then
  VALID_IMPLS_FOR_STACK=$(get_valid_impls "$STACK")
  if ! contains "$IMPLEMENTATION" "$VALID_IMPLS_FOR_STACK"; then
    echo -e "${RED}Error: '$IMPLEMENTATION' is not valid for stack '$STACK'. Valid: $VALID_IMPLS_FOR_STACK${NC}" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -n "$JSON" ]] && ! contains "$JSON" "$VALID_JSON"; then
  echo -e "${RED}Error: Invalid json '$JSON'. Valid: $VALID_JSON${NC}" >&2
  echo -e "${YELLOW}Use --raw to bypass validation.${NC}" >&2
  errors=$((errors + 1))
fi

if [[ -n "$SCALA_VERSION" ]] && ! contains "$SCALA_VERSION" "$VALID_SCALA"; then
  echo -e "${RED}Error: Invalid scala '$SCALA_VERSION'. Valid: $VALID_SCALA${NC}" >&2
  errors=$((errors + 1))
fi

if [[ -n "$BUILDER" ]] && ! contains "$BUILDER" "$VALID_BUILDER"; then
  echo -e "${RED}Error: Invalid builder '$BUILDER'. Valid: $VALID_BUILDER${NC}" >&2
  errors=$((errors + 1))
fi

if [[ $errors -gt 0 ]]; then
  echo -e "${YELLOW}If the API has changed, use --raw with an updated payload.${NC}" >&2
  exit 1
fi

# ── Build JSON ──

PAYLOAD=$(cat <<EOF
{
  "projectName": "$PROJECT_NAME",
  "groupId": "$GROUP_ID",
  "stack": "$STACK",
  "implementation": "$IMPLEMENTATION",
  "json": "$JSON",
  "scalaVersion": "$SCALA_VERSION",
  "builder": "$BUILDER",
  "addDocumentation": $DOCS,
  "addMetrics": $METRICS
}
EOF
)

echo ""
echo -e "${BLUE}=== Generating Tapir Project ===${NC}"
echo "  Name:          $PROJECT_NAME"
echo "  Group:         $GROUP_ID"
echo "  Stack:         $STACK"
echo "  Implementation: $IMPLEMENTATION"
echo "  JSON:          $JSON"
echo "  Scala:         $SCALA_VERSION"
echo "  Builder:       $BUILDER"
echo "  Docs:          $DOCS"
echo "  Metrics:       $METRICS"
echo ""

# ── Request ──

ZIP_NAME="${PROJECT_NAME}.zip"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_NAME}"

echo -e "${GREEN}Requesting project from adopt-tapir...${NC}"
HTTP_CODE=$(curl -s -o "$ZIP_NAME" -w "%{http_code}" \
  -X POST "$API_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/zip' \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo -e "${RED}API returned HTTP $HTTP_CODE${NC}" >&2
  echo -e "${RED}Response saved to $ZIP_NAME for inspection.${NC}" >&2
  echo ""
  echo -e "${YELLOW}The API field names or valid values may have changed.${NC}" >&2
  echo -e "${YELLOW}Fallback options:${NC}" >&2
  echo -e "${YELLOW}  1. Inspect the form at https://adopt-tapir.softwaremill.com/${NC}" >&2
  echo -e "${YELLOW}  2. Check the API source at https://github.com/softwaremill/adopt-tapir${NC}" >&2
  echo -e "${YELLOW}  3. Re-run with --raw and an updated JSON payload:${NC}" >&2
  echo -e "${YELLOW}     $0 --raw '<updated-json>'${NC}" >&2
  echo ""
  echo -e "${YELLOW}Payload that failed:${NC}" >&2
  echo "$PAYLOAD" >&2
  exit 1
fi

# ── Extract ──

mkdir -p "$OUTPUT_DIR"
unzip -q -o "$ZIP_NAME" -d "$OUTPUT_DIR"
rm -f "$ZIP_NAME"

echo ""
echo -e "${GREEN}Project created in $OUTPUT_DIR/${NC}"
echo ""
echo "Next steps:"
echo "  cd $OUTPUT_DIR"
if [[ "$BUILDER" == "Sbt" ]]; then
  echo "  sbt run"
else
  echo "  scala-cli run ."
fi
