#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
FORCE=false INSTALLED=0 SKIPPED=0 FAILED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f) FORCE=true; shift ;;
            --help|-h) echo "Usage: $0 [--force|-f] [--help|-h]"; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done
}

check_dependencies() {
    local missing=()
    command -v jq &>/dev/null || missing+=("jq (for settings.json merge)")
    command -v python3 &>/dev/null || missing+=("python3 (for hooks)")
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing optional dependencies:"; printf "  - %s\n" "${missing[@]}"
        read -rp "Continue? [Y/n]: " r; [[ "$r" =~ ^[Nn] ]] && { log_error "Aborted."; exit 1; }
    fi
}

prompt_action() {
    [[ "$FORCE" == true ]] && { echo "overwrite"; return; }
    log_warn "File exists: $1"
    echo "  [s] Skip  [o] Overwrite  [m] Merge"
    read -rp "Choice [s/o/m]: " c
    case "$c" in o|O) echo "overwrite" ;; m|M) echo "merge" ;; *) echo "skip" ;; esac
}

install_file() {
    mkdir -p "$(dirname "$2")"
    [[ "$1" -ef "$2" ]] && { log_info "Same file: $2"; ((SKIPPED++)) || true; return 0; }
    if [[ -f "$2" ]]; then
        case "$(prompt_action "$2")" in
            skip) log_info "Skipped: $2"; ((SKIPPED++)) || true ;;
            overwrite) cp "$1" "$2"; log_success "Overwrote: $2"; ((INSTALLED++)) || true ;;
            merge) cp "$2" "${2}.backup"; cp "$1" "${2}.new"; log_warn "Created ${2}.new - merge needed"; ((SKIPPED++)) || true ;;
        esac
    else cp "$1" "$2"; log_success "Installed: $2"; ((INSTALLED++)) || true; fi
}

install_dir() {
    [[ ! -d "$1" ]] && { log_warn "Missing: $1"; return 1; }
    find "$1" -type f -name "${3:-*}" | while read -r src; do
        install_file "$src" "$2/${src#$1/}"
    done
}

merge_settings() {
    local sf="$CLAUDE_DIR/settings.json" ef="$SCRIPT_DIR/settings.json.example"
    [[ ! -f "$ef" ]] && { log_warn "settings.json.example not found"; return 0; }
    if [[ ! -f "$sf" ]]; then cp "$ef" "$sf"; log_success "Created: $sf"; ((INSTALLED++)) || true; return 0; fi
    if ! command -v jq &>/dev/null; then
        log_warn "jq not installed - manual merge needed"; cat "$ef"; return 0
    fi
    if jq -e '.hooks' "$sf" &>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            jq -s '.[0] * .[1]' "$sf" "$ef" > "${sf}.tmp" && mv "${sf}.tmp" "$sf"
            log_success "Merged hooks into: $sf"; ((INSTALLED++)) || true
        else
            log_warn "Existing hooks in settings.json"
            read -rp "[s]kip/[m]erge/[r]eplace: " c
            case "$c" in
                m|M) jq -s '.[0] as $e | .[1] as $n | $e * {hooks:(($e.hooks // {}) | keys) + (($n.hooks // {}) | keys) | unique | map(. as $k | {($k): (($e.hooks[$k] // []) + ($n.hooks[$k] // []))}) | add}' "$sf" "$ef" > "${sf}.tmp" && mv "${sf}.tmp" "$sf"; log_success "Merged"; ((INSTALLED++)) || true ;;
                r|R) jq -s '.[0] * .[1]' "$sf" "$ef" > "${sf}.tmp" && mv "${sf}.tmp" "$sf"; log_success "Replaced"; ((INSTALLED++)) || true ;;
                *) log_info "Skipped"; ((SKIPPED++)) || true ;;
            esac
        fi
    else
        jq -s '.[0] * .[1]' "$sf" "$ef" > "${sf}.tmp" && mv "${sf}.tmp" "$sf"
        log_success "Added hooks to: $sf"; ((INSTALLED++)) || true
    fi
}

migrate_skills() {
    local sd="$CLAUDE_DIR/skills" m=0
    local -a OLD=(brainstorming compound dispatching-parallel-agents executing-plans finishing-a-development-branch managing-plans react-useeffect receiving-code-review requesting-code-review review subagent-driven-development systematic-debugging test-driven-development using-git-worktrees using-workflows verification-before-completion writing-skills)
    local -a NEW=(Brainstorming Compound DispatchingParallelAgents ExecutingPlans FinishingDevelopmentBranch ManagingPlans ReactUseEffect ReceivingCodeReview RequestingCodeReview Review SubagentDrivenDevelopment SystematicDebugging TestDrivenDevelopment UsingGitWorktrees UsingWorkflows VerificationBeforeCompletion WritingSkills)
    for i in "${!OLD[@]}"; do
        [[ -d "$sd/${OLD[$i]}" ]] && { rm -rf "$sd/${OLD[$i]}"; log_info "Removed: ${OLD[$i]}"; ((m++)) || true; }
    done
    [[ $m -gt 0 ]] && log_success "Migrated $m legacy skills"
}

main() {
    parse_args "$@"
    echo -e "\n==========================================\n  Claude Code Config Installer\n==========================================\n"
    log_info "Source: $SCRIPT_DIR"; log_info "Destination: $CLAUDE_DIR"
    [[ "$FORCE" == true ]] && log_info "Mode: Force"
    check_dependencies
    mkdir -p "$CLAUDE_DIR"
    log_info "Installing rules..."; install_dir "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules" "*.md"
    log_info "Migrating skills..."; migrate_skills
    log_info "Installing skills..."; install_dir "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills" "*.md"
    log_info "Installing agents..."; install_dir "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents" "*.md"
    log_info "Installing prompts..."; install_dir "$SCRIPT_DIR/prompts" "$CLAUDE_DIR/prompts" "*.md"
    log_info "Installing commands..."; install_dir "$SCRIPT_DIR/commands" "$CLAUDE_DIR/commands" "*.md"
    log_info "Installing hooks..."; install_dir "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks" "*.py"; install_dir "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks" "*.sh"
    log_info "Installing config..."; install_dir "$SCRIPT_DIR/config" "$CLAUDE_DIR/config" "*.json"
    log_info "Installing CLAUDE.md..."; install_file "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    [[ -d "$CLAUDE_DIR/hooks" ]] && find "$CLAUDE_DIR/hooks" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; && log_success "Made hooks executable"
    log_info "Configuring settings..."; merge_settings
    # Convert relative hook paths to absolute
    if [[ -f "$CLAUDE_DIR/settings.json" ]] && grep -q '\./hooks/' "$CLAUDE_DIR/settings.json"; then
        sed "s|\./hooks/|$CLAUDE_DIR/hooks/|g" "$CLAUDE_DIR/settings.json" > "${CLAUDE_DIR}/settings.json.tmp" && mv "${CLAUDE_DIR}/settings.json.tmp" "$CLAUDE_DIR/settings.json"
        log_success "Converted hook paths to absolute"
    fi
    echo -e "\n==========================================\n  Installation Complete\n==========================================\n"
    log_info "Installed: $INSTALLED files"; log_info "Skipped: $SKIPPED files"
    [[ $FAILED -gt 0 ]] && log_error "Failed: $FAILED files"
    log_info "Restart Claude Code for changes to take effect."
}

main "$@"
