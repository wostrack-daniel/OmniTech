#!/usr/bin/env bash

set -e

# ==========================================
# OMNI ENGINE - INTERACTIVE RELEASE SYSTEM
# ==========================================

# Sicherstellen, dass wir im Repository-Root sind
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Error: Not inside a Git repository."
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Prüfen, ob wichtige Dateien existieren
for FILE in VERSION BUILD CHANGELOG.md; do
    if [ ! -f "$FILE" ]; then
        echo "Error: Missing required file: $FILE"
        exit 1
    fi
done

# ------------------------------------------
# CURRENT VERSION
# ------------------------------------------

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: VERSION is not in X.X.X format."
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
NEXT_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

echo ""
echo "=========================================="
echo " OMNI ENGINE RELEASE"
echo "=========================================="
echo ""
echo "Current Version : $CURRENT_VERSION"
echo "Suggested Version: $NEXT_VERSION"
echo ""

read -rp "New version [Press Enter for $NEXT_VERSION]: " INPUT_VERSION

if [ -z "$INPUT_VERSION" ]; then
    NEW_VERSION="$NEXT_VERSION"
else
    NEW_VERSION="$INPUT_VERSION"
fi

# Version prüfen
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must use format X.X.X"
    exit 1
fi

# ------------------------------------------
# BUILD NUMBER
# ------------------------------------------

CURRENT_BUILD="$(tr -d '[:space:]' < BUILD)"

if [[ ! "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    echo "Error: BUILD must contain only numbers."
    exit 1
fi

NEW_BUILD=$((10#$CURRENT_BUILD + 1))
NEW_BUILD="$(printf "%06d" "$NEW_BUILD")"

echo ""
echo "Technical Build: $CURRENT_BUILD -> $NEW_BUILD"
echo ""

# ------------------------------------------
# CHANGELOG INPUT
# ------------------------------------------

echo "Enter changelog entries."
echo "Write one entry per line."
echo "Press Enter on an empty line when finished."
echo ""

CHANGELOG_ENTRIES=()

while true; do
    read -rp "> " ENTRY

    if [ -z "$ENTRY" ]; then
        break
    fi

    CHANGELOG_ENTRIES+=("$ENTRY")
done

# Falls kein Changelog eingegeben wurde
if [ ${#CHANGELOG_ENTRIES[@]} -eq 0 ]; then
    CHANGELOG_ENTRIES=("General project updates")
fi

# ------------------------------------------
# CONFIRMATION
# ------------------------------------------

echo ""
echo "=========================================="
echo " RELEASE SUMMARY"
echo "=========================================="
echo ""
echo "Version : $NEW_VERSION"
echo "Build   : $NEW_BUILD"
echo ""
echo "Changelog:"
for ENTRY in "${CHANGELOG_ENTRIES[@]}"; do
    echo "- $ENTRY"
done

echo ""
read -rp "Create this release? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Release cancelled."
    exit 0
fi

# ------------------------------------------
# UPDATE VERSION FILES
# ------------------------------------------

printf "%s\n" "$NEW_VERSION" > VERSION
printf "%s\n" "$NEW_BUILD" > BUILD

# README aktualisieren, falls diese Zeilen existieren
if [ -f README.md ]; then
    sed -i -E \
        -e "s/(Public Version: )[0-9]+\.[0-9]+\.[0-9]+/\1$NEW_VERSION/" \
        -e "s/(Technical Build: )[0-9]+/\1$NEW_BUILD/" \
        README.md
fi

# ------------------------------------------
# CREATE CHANGELOG ENTRY
# ------------------------------------------

TEMP_CHANGELOG="$(mktemp)"

{
    echo "# Changelog"
    echo ""
    echo "All notable changes to OmniTech will be documented in this file."
    echo ""
    echo "## [$NEW_VERSION] - $(date +%Y-%m-%d)"
    echo ""
    echo "### Changed"

    for ENTRY in "${CHANGELOG_ENTRIES[@]}"; do
        echo "- $ENTRY"
    done

    echo ""
    echo "---"
    echo ""

    # Alten Changelog ohne Header übernehmen
    tail -n +5 CHANGELOG.md
} > "$TEMP_CHANGELOG"

mv "$TEMP_CHANGELOG" CHANGELOG.md

# ------------------------------------------
# GIT COMMIT
# ------------------------------------------

git add .

git commit -m "$NEW_VERSION"

# Optionaler Tag
if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    echo "Warning: Tag v$NEW_VERSION already exists. Skipping tag."
else
    git tag "v$NEW_VERSION"
fi

echo ""
echo "=========================================="
echo " RELEASE CREATED"
echo "=========================================="
echo ""
echo "Public Version : $NEW_VERSION"
echo "Technical Build: $NEW_BUILD"
echo "Commit         : $NEW_VERSION"
echo "Tag            : v$NEW_VERSION"
echo ""

read -rp "Push release to GitHub? [y/N]: " PUSH_CONFIRM

if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    git push
    git push origin "v$NEW_VERSION"

    echo ""
    echo "Release pushed successfully."
else
    echo ""
    echo "Release created locally."
    echo "Run 'git push && git push origin v$NEW_VERSION' later to push it."
fi
