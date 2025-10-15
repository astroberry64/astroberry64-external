#!/bin/bash
set -euo pipefail

# check-all-updates.sh - Check for new versions of external packages
# Usage: ./scripts/check-all-updates.sh [--all|--packages PKG1,PKG2] [--test-mode] [--commit]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$REPO_ROOT/packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_update() {
    echo -e "${CYAN}[UPDATE]${NC} $*"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Check for new versions of external packages and optionally update config files.

Options:
  --all                Check all packages in packages/ directory
  --packages PKG1,PKG2 Check only specified packages (comma-separated)
  --test-mode          Print what would be updated without modifying files
  --dry-run            Alias for --test-mode
  --commit             Commit each package update separately (requires git)
  --help               Show this help message

Examples:
  $0 --all                           # Check all packages
  $0 --packages indi,phd2            # Check only INDI and PHD2
  $0 --all --test-mode               # Check all but don't modify files
  $0 --packages indi --commit        # Check INDI and commit if updated

Environment:
  GITHUB_TOKEN         GitHub personal access token (for API rate limits)

EOF
    exit 1
}

# Parse arguments
CHECK_ALL=0
CHECK_PACKAGES=""
TEST_MODE=0
DO_COMMIT=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CHECK_ALL=1
            shift
            ;;
        --packages)
            CHECK_PACKAGES="$2"
            shift 2
            ;;
        --test-mode|--dry-run)
            TEST_MODE=1
            shift
            ;;
        --commit)
            DO_COMMIT=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [ $CHECK_ALL -eq 0 ] && [ -z "$CHECK_PACKAGES" ]; then
    log_error "Must specify --all or --packages"
    usage
fi

if [ $CHECK_ALL -eq 1 ] && [ -n "$CHECK_PACKAGES" ]; then
    log_error "Cannot use both --all and --packages"
    usage
fi

# Build package list
PACKAGES_TO_CHECK=()
if [ $CHECK_ALL -eq 1 ]; then
    log_info "Checking all packages..."
    for pkg_dir in "$PACKAGES_DIR"/*; do
        if [ -d "$pkg_dir" ] && [ -f "$pkg_dir/config.sh" ]; then
            PACKAGES_TO_CHECK+=("$(basename "$pkg_dir")")
        fi
    done
else
    log_info "Checking specified packages: $CHECK_PACKAGES"
    IFS=',' read -ra PACKAGES_TO_CHECK <<< "$CHECK_PACKAGES"
fi

if [ ${#PACKAGES_TO_CHECK[@]} -eq 0 ]; then
    log_warn "No packages found to check"
    exit 0
fi

log_info "Packages to check: ${PACKAGES_TO_CHECK[*]}"

# Version comparison using sort -V (handles semantic versioning)
version_greater_than() {
    local ver1="$1"
    local ver2="$2"

    # Remove 'v' prefix if present for comparison
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # Use sort -V to compare versions
    local sorted=$(printf "%s\n%s\n" "$ver1" "$ver2" | sort -V)
    local first=$(echo "$sorted" | head -n1)

    # If ver2 comes first when sorted, then ver1 > ver2
    [ "$first" = "$ver2" ] && [ "$ver1" != "$ver2" ]
}

# Check for updates for a specific SOURCE_TYPE
check_git_version() {
    local pkg_name="$1"
    local git_repo="$2"
    local current_tag="$3"

    log_info "Checking git repo: $git_repo (current: $current_tag)" >&2

    # Extract owner/repo from git URL
    local repo_path
    if [[ $git_repo =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
        repo_path="${BASH_REMATCH[1]}"
        repo_path="${repo_path%.git}"
    else
        log_warn "Cannot extract GitHub repo from: $git_repo" >&2
        return 1
    fi

    # Query GitHub API for latest release
    local api_url="https://api.github.com/repos/$repo_path/releases/latest"
    local auth_header=""
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header="Authorization: Bearer $GITHUB_TOKEN"
    fi

    local response
    if [ -n "$auth_header" ]; then
        response=$(curl -s -H "$auth_header" "$api_url")
    else
        response=$(curl -s "$api_url")
    fi

    local latest_tag=$(echo "$response" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [ -z "$latest_tag" ]; then
        log_warn "Could not fetch latest release for $repo_path" >&2
        return 1
    fi

    log_info "Latest version: $latest_tag" >&2

    if version_greater_than "$latest_tag" "$current_tag"; then
        log_update "$pkg_name: $current_tag → $latest_tag" >&2
        echo "$latest_tag"
        return 0
    else
        log_info "$pkg_name is up to date ($current_tag)" >&2
        return 1
    fi
}

# Check git tags (alternative to releases, includes dev tags)
check_git_tags_version() {
    local pkg_name="$1"
    local git_repo="$2"
    local current_tag="$3"
    local include_prerelease="${4:-true}"

    log_info "Checking git tags: $git_repo (current: $current_tag)" >&2

    # Extract owner/repo from git URL
    local repo_path
    if [[ $git_repo =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
        repo_path="${BASH_REMATCH[1]}"
        repo_path="${repo_path%.git}"
    else
        log_warn "Cannot extract GitHub repo from: $git_repo" >&2
        return 1
    fi

    # Query GitHub API for tags
    local api_url="https://api.github.com/repos/$repo_path/tags"
    local auth_header=""
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header="Authorization: Bearer $GITHUB_TOKEN"
    fi

    local response
    if [ -n "$auth_header" ]; then
        response=$(curl -s -H "$auth_header" "$api_url")
    else
        response=$(curl -s "$api_url")
    fi

    # Check if jq is available for better parsing
    if ! command -v jq &> /dev/null; then
        log_warn "jq not installed, using basic parsing" >&2
        local latest_tag=$(echo "$response" | grep -o '"name": *"[^"]*"' | head -1 | sed 's/.*"name": *"\([^"]*\)".*/\1/')
    else
        # Use jq for proper JSON parsing and filtering
        if [ "$include_prerelease" = "false" ]; then
            # Filter out prerelease tags (dev, rc, beta, alpha)
            latest_tag=$(echo "$response" | jq -r '[.[] | select(.name | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$"))] | .[0].name')
        else
            # Include all tags
            latest_tag=$(echo "$response" | jq -r '.[0].name')
        fi
    fi

    if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
        log_warn "Could not fetch latest tag for $repo_path" >&2
        return 1
    fi

    log_info "Latest version: $latest_tag" >&2

    if version_greater_than "$latest_tag" "$current_tag"; then
        log_update "$pkg_name: $current_tag → $latest_tag" >&2
        echo "$latest_tag"
        return 0
    else
        log_info "$pkg_name is up to date ($current_tag)" >&2
        return 1
    fi
}

check_ppa_version() {
    local pkg_name="$1"
    local ppa_name="$2"
    local package_name="$3"

    log_info "Checking PPA: $ppa_name for package: $package_name"
    log_warn "PPA version checking not yet implemented"
    return 1
}

check_github_release_version() {
    # Same as check_git_version for GitHub releases
    check_git_version "$@"
}

# Update config file with new version
update_config_file() {
    local config_file="$1"
    local old_value="$2"
    local new_value="$3"

    if [ $TEST_MODE -eq 1 ]; then
        log_info "[DRY RUN] Would update $config_file: $old_value → $new_value"
        return 0
    fi

    # Use sed to replace the version in config file
    sed -i "s|$old_value|$new_value|g" "$config_file"
    log_success "Updated $config_file"
}

# Main checking loop
UPDATES_FOUND=0
UPDATED_PACKAGES=()

for pkg in "${PACKAGES_TO_CHECK[@]}"; do
    PKG_DIR="$PACKAGES_DIR/$pkg"
    CONFIG_FILE="$PKG_DIR/config.sh"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "Config file not found: $CONFIG_FILE"
        continue
    fi

    log_info "Checking package: $pkg"

    # Source the config file
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    # Determine which version check method to use
    VERSION_CHECK_SOURCE="${VERSION_SOURCE:-github-releases}"  # Default to github-releases for backwards compatibility
    VERSION_INCLUDE_PRERELEASE="${VERSION_INCLUDE_PRERELEASE:-false}"

    # Check based on VERSION_SOURCE (or fall back to SOURCE_TYPE for compatibility)
    NEW_VERSION=""
    case "$VERSION_CHECK_SOURCE" in
        git-tags)
            # Check git tags instead of releases
            if [ "${SOURCE_TYPE:-}" = "git" ]; then
                if NEW_VERSION=$(check_git_tags_version "$pkg" "$GIT_REPO" "$GIT_TAG" "$VERSION_INCLUDE_PRERELEASE"); then
                    update_config_file "$CONFIG_FILE" "GIT_TAG=\"$GIT_TAG\"" "GIT_TAG=\"$NEW_VERSION\""
                    UPDATES_FOUND=$((UPDATES_FOUND + 1))
                    UPDATED_PACKAGES+=("$pkg")

                    # Commit if requested
                    if [ $DO_COMMIT -eq 1 ] && [ $TEST_MODE -eq 0 ]; then
                        cd "$REPO_ROOT"
                        git add "$CONFIG_FILE"
                        git commit -m "Auto-update $pkg to $NEW_VERSION"$'\n\n'"Updated GIT_TAG from $GIT_TAG to $NEW_VERSION"$'\n\n'"🤖 Automated version check"
                        log_success "Committed update for $pkg"
                    fi
                fi
            else
                log_warn "$pkg: VERSION_SOURCE=git-tags requires SOURCE_TYPE=git"
            fi
            ;;
        github-releases)
            # Check GitHub releases (original behavior)
            if [ "${SOURCE_TYPE:-}" = "git" ]; then
                if NEW_VERSION=$(check_git_version "$pkg" "$GIT_REPO" "$GIT_TAG"); then
                    update_config_file "$CONFIG_FILE" "GIT_TAG=\"$GIT_TAG\"" "GIT_TAG=\"$NEW_VERSION\""
                    UPDATES_FOUND=$((UPDATES_FOUND + 1))
                    UPDATED_PACKAGES+=("$pkg")

                    # Commit if requested
                    if [ $DO_COMMIT -eq 1 ] && [ $TEST_MODE -eq 0 ]; then
                        cd "$REPO_ROOT"
                        git add "$CONFIG_FILE"
                        git commit -m "Auto-update $pkg to $NEW_VERSION"$'\n\n'"Updated GIT_TAG from $GIT_TAG to $NEW_VERSION"$'\n\n'"🤖 Automated version check"
                        log_success "Committed update for $pkg"
                    fi
                fi
            else
                log_warn "$pkg: VERSION_SOURCE=github-releases requires SOURCE_TYPE=git"
            fi
            ;;
        ppa)
            log_warn "$pkg: PPA version checking not yet implemented"
            ;;
        custom)
            log_info "$pkg: Custom version checking configured, skipping automated check"
            ;;
        *)
            log_warn "$pkg: Unknown VERSION_SOURCE: $VERSION_CHECK_SOURCE"
            ;;
    esac

    echo ""  # Blank line between packages
done

# Summary
echo "========================================"
if [ $UPDATES_FOUND -eq 0 ]; then
    log_success "All packages are up to date!"
else
    log_update "Found $UPDATES_FOUND update(s): ${UPDATED_PACKAGES[*]}"
    if [ $TEST_MODE -eq 1 ]; then
        log_info "Run without --test-mode to apply updates"
    fi
fi

exit 0
