#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../../core/templates" && pwd)"

if [ ! -d "$TEMPLATES_DIR/ui" ] || [ ! -d "$TEMPLATES_DIR/api" ]; then
  echo "Error: Template directory not found at $TEMPLATES_DIR" >&2
  exit 1
fi

# --- Parse CLI arguments ---

ARG_UI_NAME=""
ARG_API_NAME=""
ARG_CONTRACT_PACKAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ui-name)
      ARG_UI_NAME="$2"
      shift 2
      ;;
    --api-name)
      ARG_API_NAME="$2"
      shift 2
      ;;
    --contract-package)
      ARG_CONTRACT_PACKAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: init.sh [--ui-name <name>] [--api-name <name>] [--contract-package <pkg>]" >&2
      exit 1
      ;;
  esac
done

# --- Step 1: Derive values ---

PROJECT_NAME=""
if [ -f "package.json" ]; then
  PROJECT_NAME=$(python3 -c "import json; print(json.load(open('package.json')).get('name', ''))" 2>/dev/null || echo "")
fi
PROJECT_NAME="${PROJECT_NAME:-my-midnight-dapp}"

CONTRACT_PACKAGE=""
for dir in */src/managed/*/; do
  if [ -d "$dir" ]; then
    contract_pkg_dir=$(dirname "$(dirname "$(dirname "$dir")")")
    if [ -f "$contract_pkg_dir/package.json" ]; then
      CONTRACT_PACKAGE=$(python3 -c "import json; print(json.load(open('$contract_pkg_dir/package.json')).get('name', ''))" 2>/dev/null || echo "")
      break
    fi
  fi
done

# Apply CLI arguments or defaults
UI_DIR="${ARG_UI_NAME:-ui}"
API_DIR="${ARG_API_NAME:-api}"
CONTRACT_PACKAGE="${ARG_CONTRACT_PACKAGE:-${CONTRACT_PACKAGE:-@${PROJECT_NAME}/contract}}"

PACKAGE_MANAGER="npm"
if [ -f "pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
elif [ -f "yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
elif [ -f "package-lock.json" ]; then
  PACKAGE_MANAGER="npm"
fi

# --- Step 2: Display resolved configuration ---

UI_PACKAGE_NAME="${PROJECT_NAME}-ui"
API_PACKAGE_NAME="${PROJECT_NAME}-api"

echo ""
echo "Scaffolding with:"
echo "  Project:    $PROJECT_NAME"
echo "  UI:         $UI_DIR/ ($UI_PACKAGE_NAME)"
echo "  API:        $API_DIR/ ($API_PACKAGE_NAME)"
echo "  Contract:   $CONTRACT_PACKAGE"
echo "  Pkg mgr:    $PACKAGE_MANAGER"
echo ""

# --- Step 3: Copy and substitute ---

if [ -d "$UI_DIR" ]; then
  echo "Error: Directory '$UI_DIR' already exists." >&2
  exit 1
fi

if [ -d "$API_DIR" ]; then
  echo "Error: Directory '$API_DIR' already exists." >&2
  exit 1
fi

cp -r "$TEMPLATES_DIR/ui" "$UI_DIR"
cp -r "$TEMPLATES_DIR/api" "$API_DIR"

# Run substitution across all files
find "$UI_DIR" "$API_DIR" -type f | while read -r file; do
  if file "$file" | grep -q text; then
    sed -i'' -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$file"
    sed -i'' -e "s|{{UI_PACKAGE_NAME}}|$UI_PACKAGE_NAME|g" "$file"
    sed -i'' -e "s|{{API_PACKAGE_NAME}}|$API_PACKAGE_NAME|g" "$file"
    sed -i'' -e "s|{{UI_DIR}}|$UI_DIR|g" "$file"
    sed -i'' -e "s|{{API_DIR}}|$API_DIR|g" "$file"
    sed -i'' -e "s|{{CONTRACT_PACKAGE}}|$CONTRACT_PACKAGE|g" "$file"
    sed -i'' -e "s|{{PACKAGE_MANAGER}}|$PACKAGE_MANAGER|g" "$file"
    # Clean up sed backup files on macOS
    rm -f "${file}-e"
  fi
done

# --- Step 4: Post-scaffold ---

# Add workspaces to root package.json if it exists and has workspaces
if [ -f "package.json" ]; then
  if python3 -c "import json; d=json.load(open('package.json')); exit(0 if 'workspaces' in d else 1)" 2>/dev/null; then
    python3 -c "
import json
with open('package.json', 'r') as f:
    data = json.load(f)
ws = data.get('workspaces', [])
if isinstance(ws, dict):
    ws = ws.get('packages', [])
for d in ['$UI_DIR', '$API_DIR']:
    if d not in ws:
        ws.append(d)
if isinstance(data.get('workspaces'), dict):
    data['workspaces']['packages'] = ws
else:
    data['workspaces'] = ws
with open('package.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null || echo "Note: Could not update workspaces in package.json. Add '$UI_DIR' and '$API_DIR' manually."
  fi
fi

echo ""
echo "Done! Next steps:"
echo ""
echo "  1. $PACKAGE_MANAGER install"
echo "  2. Configure copy-contract-keys in $UI_DIR/package.json"
echo "  3. Wire up your contract in $API_DIR/src/index.ts"
echo "  4. cd $UI_DIR && $PACKAGE_MANAGER run dev"
echo ""
