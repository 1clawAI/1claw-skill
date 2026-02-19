#!/usr/bin/env bash
# Validate the 1claw skill for OpenClaw / ClawHub compatibility.
# Run from repo root: ./skill/scripts/validate.sh
# Or from skill dir: ./scripts/validate.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SKILL_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAIL=0

echo "Validating 1claw skill in: $SKILL_DIR"
echo ""

# Required files (ClawHub / OpenClaw)
REQUIRED_FILES=(SKILL.md README.md)
for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo -e "${GREEN}✓${NC} $f exists"
  else
    echo -e "${RED}✗${NC} $f missing"
    FAIL=1
  fi
done

# Supporting docs
SUPPORT_FILES=(CONFIG.md EXAMPLES.md)
for f in "${SUPPORT_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo -e "${GREEN}✓${NC} $f exists"
  else
    echo -e "${YELLOW}!${NC} $f missing (optional but recommended)"
  fi
done

# SKILL.md frontmatter (ClawHub metadata)
if grep -q '^---$' SKILL.md && grep -q '^name:' SKILL.md && grep -q '^description:' SKILL.md; then
  echo -e "${GREEN}✓${NC} SKILL.md has YAML frontmatter (name, description)"
else
  echo -e "${RED}✗${NC} SKILL.md should have YAML frontmatter with name and description"
  FAIL=1
fi

# Tool names documented in SKILL.md must match MCP server
MCP_TOOLS=(
  list_secrets get_secret put_secret delete_secret describe_secret
  rotate_and_store get_env_bundle create_vault list_vaults grant_access share_secret
)
for tool in "${MCP_TOOLS[@]}"; do
  if grep -q "$tool" SKILL.md; then
    echo -e "${GREEN}✓${NC} Tool documented: $tool"
  else
    echo -e "${RED}✗${NC} Tool missing from SKILL.md: $tool"
    FAIL=1
  fi
done

# README mentions OpenClaw / ClawHub
if grep -qi 'openclaw\|clawhub' README.md; then
  echo -e "${GREEN}✓${NC} README mentions OpenClaw/ClawHub"
else
  echo -e "${YELLOW}!${NC} README does not mention OpenClaw/ClawHub"
fi

echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All required checks passed.${NC} Skill is ready for OpenClaw bots and ClawHub."
  if command -v clawhub &>/dev/null; then
    echo ""
    echo "ClawHub CLI is installed. To install this skill locally:"
    echo "  clawhub install 1claw"
    echo "Or publish (from skill dir):"
    echo "  clawhub publish . --slug 1claw --name \"1Claw\" --version 1.0.0 --tags latest"
  fi
  exit 0
else
  echo -e "${RED}Some checks failed.${NC} Fix the issues above before publishing."
  exit 1
fi
