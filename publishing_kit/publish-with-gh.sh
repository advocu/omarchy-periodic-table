#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <your-github-username> [--submit-marketplace]"
  exit 1
fi

GH_USER="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
SUBMIT_FLAG="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../omarchy-periodic-table" && pwd)"
PLUGIN_ID="io.github.${GH_USER}.periodic-table"

echo "==> Step 1: Updating plugin namespace to ${PLUGIN_ID}..."
sed -i "s/io\.github\.advocatus\.periodic-table/${PLUGIN_ID}/g" \
  "$REPO_DIR/manifest.json" \
  "$REPO_DIR/BarWidget.qml" \
  "$REPO_DIR/Panel.qml" \
  "$REPO_DIR/README.md"
sed -i "s|github.com/advocatus/omarchy-periodic-table|github.com/${GH_USER}/omarchy-periodic-table|g" \
  "$REPO_DIR/README.md"

echo "==> Step 2: Installing into ~/.config/omarchy/plugins/${PLUGIN_ID} for local testing..."
mkdir -p "$HOME/.config/omarchy/plugins"
rm -rf "$HOME/.config/omarchy/plugins/${PLUGIN_ID}"
cp -R "$REPO_DIR" "$HOME/.config/omarchy/plugins/${PLUGIN_ID}"

if command -v omarchy >/dev/null 2>&1; then
  echo "==> Step 3: Running omarchy plugin validate..."
  omarchy plugin validate "$HOME/.config/omarchy/plugins/${PLUGIN_ID}"
fi

if command -v qmllint >/dev/null 2>&1 && [ -n "${OMARCHY_PATH:-}" ]; then
  echo "==> Step 4: Running qmllint against $OMARCHY_PATH/shell..."
  qmllint -I "$OMARCHY_PATH/shell" \
    "$HOME/.config/omarchy/plugins/${PLUGIN_ID}/BarWidget.qml" \
    "$HOME/.config/omarchy/plugins/${PLUGIN_ID}/Panel.qml" \
    "$HOME/.config/omarchy/plugins/${PLUGIN_ID}/BohrCanvas.qml"
fi

echo "==> Step 5: Initializing Git repository in $REPO_DIR..."
cd "$REPO_DIR"
git init -b main
git add manifest.json BarWidget.qml Panel.qml BohrCanvas.qml ElementsData.js preview.png README.md LICENSE
git commit -m "Initial release of Periodic Table (${PLUGIN_ID}) v1.0.0 for Omarchy Quattro"

if command -v gh >/dev/null 2>&1; then
  echo "==> Step 6: Creating public GitHub repository ${GH_USER}/omarchy-periodic-table and pushing..."
  gh repo create "${GH_USER}/omarchy-periodic-table" --public --source=. --remote=origin --push

  ISSUE_FILE="/tmp/omarchy-periodic-table-submission.md"
  sed "s/GITHUB_USERNAME/${GH_USER}/g" "$SCRIPT_DIR/SUBMISSION_ISSUE_BODY.md" > "$ISSUE_FILE"
  echo "==> Prepared Marketplace issue body at: $ISSUE_FILE"

  if [ "$SUBMIT_FLAG" = "--submit-marketplace" ]; then
    echo "==> Submitting issue to omacom/omarchy-plugin-marketplace..."
    gh issue create \
      --repo omacom/omarchy-plugin-marketplace \
      --title "[Plugin]: Periodic Table" \
      --body-file "$ISSUE_FILE"
  else
    echo "To submit directly to the Omarchy Plugin Marketplace now, re-run with --submit-marketplace or run:"
    echo "  gh issue create --repo omacom/omarchy-plugin-marketplace --title "[Plugin]: Periodic Table" --body-file $ISSUE_FILE"
  fi
fi
