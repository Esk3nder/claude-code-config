#!/usr/bin/env bash
#
# Claude Code Config Installer
# Copies configuration files to ~/.claude/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Track installation stats
INSTALLED=0
SKIPPED=0
FAILED=0

# Prompt for user action when file exists
# Returns: "skip", "overwrite", or "merge"
prompt_action() {
    local dest="$1"
    echo ""
    log_warn "File already exists: $dest"
    echo "  [s] Skip - keep existing file"
    echo "  [o] Overwrite - replace with new version"
    echo "  [m] Merge - try to combine (manual review needed)"
    echo ""
    read -rp "Choice [s/o/m]: " choice
    case "$choice" in
        o|O) echo "overwrite" ;;
        m|M) echo "merge" ;;
        *)   echo "skip" ;;
    esac
}

# Install a single file
install_file() {
    local src="$1"
    local dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    # Create destination directory if needed
    mkdir -p "$dest_dir"

    if [[ -f "$dest" ]]; then
        action=$(prompt_action "$dest")
        case "$action" in
            skip)
                log_info "Skipped: $dest"
                ((SKIPPED++))
                return 0
                ;;
            overwrite)
                cp "$src" "$dest"
                log_success "Overwrote: $dest"
                ((INSTALLED++))
                ;;
            merge)
                # Create backup and copy new file
                cp "$dest" "${dest}.backup"
                cp "$src" "${dest}.new"
                log_warn "Created ${dest}.new and ${dest}.backup - manual merge needed"
                ((SKIPPED++))
                ;;
        esac
    else
        cp "$src" "$dest"
        log_success "Installed: $dest"
        ((INSTALLED++))
    fi
}

# Install a directory recursively
install_dir() {
    local src_dir="$1"
    local dest_dir="$2"
    local pattern="${3:-*}"

    if [[ ! -d "$src_dir" ]]; then
        log_warn "Source directory not found: $src_dir"
        return 1
    fi

    find "$src_dir" -type f -name "$pattern" | while read -r src; do
        local relative="${src#$src_dir/}"
        local dest="$dest_dir/$relative"
        install_file "$src" "$dest"
    done
}

# Merge settings.json hooks
merge_settings() {
    local settings_file="$CLAUDE_DIR/settings.json"
    local example_file="$SCRIPT_DIR/settings.json.example"

    if [[ ! -f "$example_file" ]]; then
        log_warn "settings.json.example not found, skipping hook wiring"
        return 0
    fi

    if [[ -f "$settings_file" ]]; then
        log_info "Existing settings.json found"
        log_warn "Please manually merge hooks from settings.json.example"
        log_info "Example hooks configuration:"
        cat "$example_file"
        echo ""
    else
        cp "$example_file" "$settings_file"
        log_success "Created: $settings_file"
        ((INSTALLED++))
    fi
}

# Make hooks executable
make_hooks_executable() {
    local hooks_dir="$CLAUDE_DIR/hooks"
    if [[ -d "$hooks_dir" ]]; then
        find "$hooks_dir" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
        log_success "Made hooks executable"
    fi
}

main() {
    echo ""
    echo "=========================================="
    echo "  Claude Code Config Installer"
    echo "=========================================="
    echo ""
    log_info "Source: $SCRIPT_DIR"
    log_info "Destination: $CLAUDE_DIR"
    echo ""

    # Create base directory
    mkdir -p "$CLAUDE_DIR"

    # Install components
    log_info "Installing rules..."
    install_dir "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules" "*.md"

    log_info "Installing skills..."
    install_dir "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills" "*.md"

    log_info "Installing agents..."
    install_dir "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents" "*.md"

    log_info "Installing prompts..."
    install_dir "$SCRIPT_DIR/prompts" "$CLAUDE_DIR/prompts" "*.md"

    log_info "Installing commands..."
    install_dir "$SCRIPT_DIR/commands" "$CLAUDE_DIR/commands" "*.md"

    log_info "Installing hooks..."
    install_dir "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks" "*.py"
    install_dir "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks" "*.sh"

    log_info "Installing config..."
    install_dir "$SCRIPT_DIR/config" "$CLAUDE_DIR/config" "*.json"

    log_info "Installing CLAUDE.md..."
    install_file "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

    # Make hooks executable
    make_hooks_executable

    # Handle settings.json
    log_info "Configuring settings.json..."
    merge_settings

    # Summary
    echo ""
    echo "=========================================="
    echo "  Installation Complete"
    echo "=========================================="
    echo ""
    log_info "Installed: $INSTALLED files"
    log_info "Skipped: $SKIPPED files"
    if [[ $FAILED -gt 0 ]]; then
        log_error "Failed: $FAILED files"
    fi
    echo ""
    log_info "Restart Claude Code for changes to take effect."
    echo ""
}

main "$@"
