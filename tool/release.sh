#!/usr/bin/env bash
#
# Cuts a release the in-app updater can actually find.
#
# Android is distributed from this project's own releases page rather than a
# store, which means two things have to be true of every build and neither is
# checked by anything else:
#
#   - the release carries an .apk asset, or the updater finds a tag and
#     nothing to install, and says nothing to anybody;
#   - it is signed with the same key as every release before it. Android
#     refuses an update signed by a different key, and the only way out for
#     somebody who has one installed is to uninstall it — losing their
#     catalogue, their history and their keystore secrets with it. There is
#     no Play App Signing to fall back on here. That key is now permanent.
#
set -euo pipefail

cd "$(dirname "$0")/.."

# The signer every OpenTV release so far has used. Compared rather than
# trusted: a machine with a different keystore in android/key.properties
# builds a perfectly valid APK that no existing install can accept.
EXPECTED_SIGNER="2b06690dd1c48aa1cc0672448842f39181cb9f07192c9189127311a1e3525e37"

if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree is dirty. Commit first — a release should name a" >&2
  echo "commit somebody can check out." >&2
  exit 1
fi

VERSION=$(grep -m1 '^version:' apps/opentv/pubspec.yaml | sed 's/^version: *//' | cut -d+ -f1)
BUILD=$(grep -m1 '^version:' apps/opentv/pubspec.yaml | sed 's/^version: *//' | cut -d+ -f2)
TAG="v${VERSION}"
APK="OpenTV-${VERSION}-${BUILD}.apk"

echo "Releasing ${TAG} (build ${BUILD})"

if ! git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "No tag ${TAG}. Tag the commit you mean to release first." >&2
  exit 1
fi

export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export LANG=en_US.UTF-8
FLUTTER=~/Development/toolchains/flutter-tvos/flutter/bin/flutter

(cd apps/opentv && "$FLUTTER" build apk --release)
BUILT=apps/opentv/build/app/outputs/flutter-apk/app-release.apk

APKSIGNER=$(ls ~/Library/Android/sdk/build-tools/*/apksigner | tail -1)
SIGNER=$("$APKSIGNER" verify --print-certs "$BUILT" 2>/dev/null \
  | grep -m1 'SHA-256 digest' | awk '{print $NF}')

if [ "$SIGNER" != "$EXPECTED_SIGNER" ]; then
  echo >&2
  echo "Refusing to publish: this build is signed by" >&2
  echo "  $SIGNER" >&2
  echo "and every release so far was signed by" >&2
  echo "  $EXPECTED_SIGNER" >&2
  echo >&2
  echo "Android will refuse this as an update to any installed copy, and the" >&2
  echo "only way out for somebody holding one is to uninstall it." >&2
  exit 1
fi
echo "Signed by the expected key."

NOTES=$(mktemp)
# The store notes are still the written ones, store or no store.
awk "/^## Release notes — ${VERSION} /{flag=1;next}/^## Release notes/{flag=0}flag" \
  docs/store-listing.md | sed '/^```$/d' | sed '/^[[:space:]]*$/d' > "$NOTES"
if [ ! -s "$NOTES" ]; then
  echo "No release notes for ${VERSION} in docs/store-listing.md." >&2
  rm -f "$NOTES"
  exit 1
fi

cp "$BUILT" "/tmp/${APK}"

if gh release view "${TAG}" >/dev/null 2>&1; then
  echo "Release ${TAG} exists — replacing its APK."
  gh release upload "${TAG}" "/tmp/${APK}" --clobber
else
  gh release create "${TAG}" "/tmp/${APK}" \
    --title "OpenTV ${VERSION}" \
    --notes-file "$NOTES"
fi
rm -f "$NOTES"

echo
echo "Published. The updater looks for this:"
gh release view "${TAG}" --json assets --jq '.assets[].name'
