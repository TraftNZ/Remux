#!/usr/bin/env bash
set -euo pipefail

#──────────────────────────────────────────────────────────────
# deploy-testflight.sh — Build & upload Remux to TestFlight
#
# Usage:
#   ./deploy-testflight.sh              # full build + upload
#   ./deploy-testflight.sh --build-only  # build archive but don't upload
#──────────────────────────────────────────────────────────────

BUILD_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --build-only)  BUILD_ONLY=true ;;
    -h|--help)
      echo "Usage: $0 [--build-only]"
      echo "  --build-only   Build the archive but don't upload to TestFlight"
      exit 0
      ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

read_dotenv_value() {
  local dotenv_key="$1"
  local dotenv_file="$2"
  local line
  local trimmed
  local value

  [ -f "$dotenv_file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    trimmed="${line#"${line%%[![:space:]]*}"}"

    case "$trimmed" in
      ""|\#*) continue ;;
    esac

    if [[ "$trimmed" == export[[:space:]]* ]]; then
      trimmed="${trimmed#export}"
      trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    fi

    if [[ "$trimmed" =~ ^${dotenv_key}[[:space:]]*=(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value#"${value%%[![:space:]]*}"}"

      if (( ${#value} >= 2 )); then
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
          value="${value:1:${#value}-2}"
          value="${value//\\\"/\"}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value="${value:1:${#value}-2}"
        fi
      fi

      printf '%s\n' "$value"
      return 0
    fi
  done < "$dotenv_file"

  return 1
}

resolve_config_value() {
  local config_key="$1"
  local default_value="$2"
  local value="${!config_key-}"

  if [ -z "$value" ]; then
    value="$(read_dotenv_value "$config_key" "$DOTENV_FILE" || true)"
  fi
  if [ -z "$value" ]; then
    value="$default_value"
  fi

  printf '%s\n' "$value"
}

resolve_app_bundle_id() {
  xcodebuild \
    -project "$PROJECT_DIR/ios/Runner.xcodeproj" \
    -scheme Runner \
    -configuration Release \
    -destination generic/platform=iOS \
    -showBuildSettings 2>/dev/null |
    awk -F' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }'
}

generate_app_store_connect_jwt() {
  local api_key_id="$1"
  local api_issuer_id="$2"
  local api_key_path="$3"
  local output
  local token

  if ! output="$(xcrun altool --generate-jwt \
    --api-key "$api_key_id" \
    --api-issuer "$api_issuer_id" \
    --p8-file-path "$api_key_path" 2>&1)"; then
    return 1
  fi

  token="$(printf '%s\n' "$output" |
    awk '/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/ { print; exit }')"
  [ -n "$token" ] || return 1

  printf '%s\n' "$token"
}

json_value() {
  local key_path="$1"

  plutil -extract "$key_path" raw -o - - 2>/dev/null || true
}

find_app_id_in_response() {
  local response_body="$1"
  local app_bundle_id="$2"
  local app_index=0
  local current_bundle_id
  local current_app_id

  while :; do
    current_bundle_id="$(printf '%s' "$response_body" | json_value "data.$app_index.attributes.bundleId")"
    [ -n "$current_bundle_id" ] || break

    if [ "$current_bundle_id" = "$app_bundle_id" ]; then
      current_app_id="$(printf '%s' "$response_body" | json_value "data.$app_index.id")"
      printf '%s\n' "$current_app_id"
      return 0
    fi

    app_index=$((app_index + 1))
  done
}

check_app_store_connect_app() {
  local app_bundle_id="$1"
  local api_key_id="$2"
  local api_issuer_id="$3"
  local api_key_path="$4"
  local jwt
  local request_url
  local http_response
  local http_status
  local response_body
  local app_id
  local next_url
  local error_code
  local error_detail

  if ! jwt="$(generate_app_store_connect_jwt "$api_key_id" "$api_issuer_id" "$api_key_path")"; then
    fail "Unable to generate App Store Connect JWT for key $api_key_id. Verify APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and $api_key_path."
  fi

  request_url="$ASC_API_BASE_URL/v1/apps"

  while [ -n "$request_url" ]; do
    if [ "$request_url" = "$ASC_API_BASE_URL/v1/apps" ]; then
      http_response="$(curl -sS -G \
        -w $'\n%{http_code}' \
        -H "Authorization: Bearer $jwt" \
        --data-urlencode "limit=$ASC_APPS_PAGE_LIMIT" \
        "$request_url")" || fail "Unable to reach App Store Connect while checking bundle ID '$app_bundle_id'."
    else
      http_response="$(curl -sS \
        -w $'\n%{http_code}' \
        -H "Authorization: Bearer $jwt" \
        "$request_url")" || fail "Unable to reach App Store Connect while checking bundle ID '$app_bundle_id'."
    fi

    http_status="${http_response##*$'\n'}"
    response_body="${http_response%$'\n'*}"

    case "$http_status" in
      200)
        app_id="$(find_app_id_in_response "$response_body" "$app_bundle_id")"
        if [ -n "$app_id" ]; then
          ok "App Store Connect app visible for $app_bundle_id"
          return 0
        fi

        next_url="$(printf '%s' "$response_body" | json_value links.next)"
        request_url="$next_url"
        ;;
      401)
        fail "App Store Connect rejected API key $api_key_id. Verify APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and $api_key_path."
        ;;
      403)
        error_code="$(printf '%s' "$response_body" | json_value errors.0.code)"
        error_detail="$(printf '%s' "$response_body" | json_value errors.0.detail)"

        if [ "$error_code" = "$ASC_REQUIRED_AGREEMENTS_ERROR_CODE" ]; then
          fail "App Store Connect agreements are missing or expired. Sign in to https://appstoreconnect.apple.com/business as the Account Holder/Admin, accept pending agreements, then rerun this script."
        fi

        fail "App Store Connect denied app lookup for '$app_bundle_id' (${error_code:-HTTP 403}). ${error_detail:-Verify API key permissions and team access.}"
        ;;
      *)
        error_code="$(printf '%s' "$response_body" | json_value errors.0.code)"
        error_detail="$(printf '%s' "$response_body" | json_value errors.0.detail)"
        fail "App Store Connect app lookup failed for '$app_bundle_id' (HTTP $http_status ${error_code:-unknown}). ${error_detail:-Rerun with a valid App Store Connect API key.}"
        ;;
    esac
  done

  fail "No App Store Connect app record found for bundle ID '$app_bundle_id'. Create the iOS app in App Store Connect, or change PRODUCT_BUNDLE_IDENTIFIER to an existing app."
}

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTENV_FILE="$PROJECT_DIR/.env"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner.xcarchive"
IPA_DIR="$PROJECT_DIR/build/ios/ipa"
EXPORT_OPTIONS="$PROJECT_DIR/ios/ExportOptions.plist"
DEFAULT_APP_STORE_CONNECT_KEY_ID="8NHAT5UHHV"
DEFAULT_APP_STORE_CONNECT_ISSUER_ID="42725b04-be15-4f93-8b52-c22bb46da07f"
ASC_API_BASE_URL="https://api.appstoreconnect.apple.com"
ASC_REQUIRED_AGREEMENTS_ERROR_CODE="FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED"
ASC_APPS_PAGE_LIMIT=50

#──────────────────────────────────────────────────────────────
# Pre-flight checks
#──────────────────────────────────────────────────────────────
step "Preparing signing keychain"
SIGNING_KEYCHAIN="${KEYCHAIN_PATH:-$(read_dotenv_value KEYCHAIN_PATH "$DOTENV_FILE" || true)}"
SIGNING_KEYCHAIN="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
[ -f "$SIGNING_KEYCHAIN" ] || fail "Signing keychain not found at $SIGNING_KEYCHAIN"

KEYCHAIN_UNLOCK_PASSWORD="${KEYCHAIN_PASSWORD:-${LOGIN_KEYCHAIN_PASSWORD:-}}"
if [ -z "$KEYCHAIN_UNLOCK_PASSWORD" ]; then
  KEYCHAIN_UNLOCK_PASSWORD="$(read_dotenv_value KEYCHAIN_PASSWORD "$DOTENV_FILE" || true)"
fi
if [ -z "$KEYCHAIN_UNLOCK_PASSWORD" ]; then
  KEYCHAIN_UNLOCK_PASSWORD="$(read_dotenv_value LOGIN_KEYCHAIN_PASSWORD "$DOTENV_FILE" || true)"
fi

if [ -z "$KEYCHAIN_UNLOCK_PASSWORD" ] && [ ! -t 0 ]; then
  fail "KEYCHAIN_PASSWORD is required to unlock $(basename "$SIGNING_KEYCHAIN") without a terminal"
fi

if [ -n "$KEYCHAIN_UNLOCK_PASSWORD" ]; then
  # The login keychain may report a failed unlock even when it is unlocked.
  security unlock-keychain -p "$KEYCHAIN_UNLOCK_PASSWORD" "$SIGNING_KEYCHAIN" >/dev/null 2>&1 || true
else
  security unlock-keychain "$SIGNING_KEYCHAIN"
fi
security show-keychain-info "$SIGNING_KEYCHAIN" >/dev/null 2>&1 ||
  fail "Signing keychain $(basename "$SIGNING_KEYCHAIN") is still locked"

# Codesign uses the first matching identity in the user keychain search list.
KEYCHAIN_SEARCH_LIST=("$SIGNING_KEYCHAIN")
while IFS= read -r keychain_path; do
  [ -n "$keychain_path" ] || continue
  [ "$keychain_path" = "$SIGNING_KEYCHAIN" ] && continue
  KEYCHAIN_SEARCH_LIST+=("$keychain_path")
done < <(security list-keychains -d user | sed 's/^ *"//; s/"$//')
security list-keychains -d user -s "${KEYCHAIN_SEARCH_LIST[@]}"

if [ -n "$KEYCHAIN_UNLOCK_PASSWORD" ]; then
  security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "$KEYCHAIN_UNLOCK_PASSWORD" "$SIGNING_KEYCHAIN" >/dev/null 2>&1 ||
    warn "Could not update codesign key access in $(basename "$SIGNING_KEYCHAIN")"
fi
ok "Keychain ready: $(basename "$SIGNING_KEYCHAIN")"

step "Pre-flight checks"

command -v flutter >/dev/null || fail "flutter not found in PATH"
command -v xcrun   >/dev/null || fail "xcrun not found — install Xcode"
command -v xcodebuild >/dev/null || fail "xcodebuild not found — install Xcode"
[ -f "$EXPORT_OPTIONS" ] || fail "ios/ExportOptions.plist not found"

ok "All tools available"

if [ "$BUILD_ONLY" = false ]; then
  step "Checking App Store Connect"

  command -v curl >/dev/null || fail "curl not found in PATH"

  API_KEY_ID="$(resolve_config_value APP_STORE_CONNECT_KEY_ID "$DEFAULT_APP_STORE_CONNECT_KEY_ID")"
  API_ISSUER_ID="$(resolve_config_value APP_STORE_CONNECT_ISSUER_ID "$DEFAULT_APP_STORE_CONNECT_ISSUER_ID")"
  API_KEY_PATH="$(resolve_config_value APP_STORE_CONNECT_KEY_PATH "$HOME/.private_keys/AuthKey_${API_KEY_ID}.p8")"
  [ -f "$API_KEY_PATH" ] || fail "App Store Connect API key not found at $API_KEY_PATH"
  APP_BUNDLE_ID="$(resolve_app_bundle_id)"

  [ -n "$APP_BUNDLE_ID" ] || fail "Unable to determine PRODUCT_BUNDLE_IDENTIFIER from the iOS Runner target"

  check_app_store_connect_app "$APP_BUNDLE_ID" "$API_KEY_ID" "$API_ISSUER_ID" "$API_KEY_PATH"
fi

#──────────────────────────────────────────────────────────────
# Auto-increment build number
#──────────────────────────────────────────────────────────────
step "Incrementing build number"

PUBSPEC="$PROJECT_DIR/pubspec.yaml"
CURRENT_VERSION=$(grep '^version:' "$PUBSPEC" | sed 's/version: //')
BUILD_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
if [[ "$CURRENT_VERSION" == *"+"* ]]; then
  BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
else
  BUILD_NUMBER=0
fi
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${BUILD_NAME}+${NEW_BUILD_NUMBER}"

sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"
ok "Version: $BUILD_NAME (build $NEW_BUILD_NUMBER)"

#──────────────────────────────────────────────────────────────
# Flutter build — archive only (skip flaky IPA export)
#──────────────────────────────────────────────────────────────
step "Installing Flutter dependencies"
flutter pub get
ok "Dependencies resolved"

step "Building Xcode archive"
rm -rf "$IPA_DIR"
flutter build ipa \
  --release \
  --no-tree-shake-icons \
  --obfuscate \
  --split-debug-info=./debug-info \
  --build-name="$BUILD_NAME" \
  --build-number="$NEW_BUILD_NUMBER" \
  --export-options-plist="$EXPORT_OPTIONS"

[ -d "$ARCHIVE_PATH" ] || fail "Archive not found at $ARCHIVE_PATH"
ok "Archive built: $ARCHIVE_PATH"

#──────────────────────────────────────────────────────────────
# Locate IPA (flutter build ipa already exported it)
#──────────────────────────────────────────────────────────────
step "Locating IPA"

IPA_PATH=$(find "$IPA_DIR" -name "*.ipa" -type f 2>/dev/null | head -1)
[ -f "$IPA_PATH" ] || fail "IPA not found in $IPA_DIR — flutter build ipa may have failed"

ok "IPA ready: $IPA_PATH"

#──────────────────────────────────────────────────────────────
# Upload to TestFlight
#──────────────────────────────────────────────────────────────
if [ "$BUILD_ONLY" = true ]; then
  warn "Skipping upload (--build-only)"
  echo ""
  ok "IPA ready at: $IPA_PATH"
  exit 0
fi

step "Uploading to TestFlight"

xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  --api-key "$API_KEY_ID" \
  --api-issuer "$API_ISSUER_ID" \
  --p8-file-path "$API_KEY_PATH"

ok "Upload complete!"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Remux $BUILD_NAME ($NEW_BUILD_NUMBER) → TestFlight${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  The build will appear in App Store Connect within ~15 minutes."
echo "  TestFlight testers will be notified once processing completes."
