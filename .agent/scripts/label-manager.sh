#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# =============================================================================
# Label Manager - Agent Pipeline GitHub Label Management
# =============================================================================
# Manages GitHub labels for the Agent pipeline using gh CLI.
# Labels are defined in .agent/labels.json and use the agent:* prefix.
#
# Usage:
#   ./label-manager.sh create-all              # Create all labels
#   ./label-manager.sh add "agent:planning" 42 # Add label to issue
#   ./label-manager.sh remove "agent:queued" 42
#
# Dependencies: gh CLI, jq
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
LABELS_FILE="${LABELS_FILE:-.agent/labels.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Check if required tools are available
check_dependencies() {
    local missing=()

    if ! command -v gh &> /dev/null; then
        missing+=("gh")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required tools: ${missing[*]}" >&2
        echo "Please install them and try again." >&2
        exit 1
    fi

    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        echo "ERROR: gh CLI is not authenticated." >&2
        echo "Run 'gh auth login' first." >&2
        exit 1
    fi
}

# Get labels file path
get_labels_file() {
    # Try relative to script dir first, then current dir
    if [[ -f "${SCRIPT_DIR}/../labels.json" ]]; then
        echo "${SCRIPT_DIR}/../labels.json"
    elif [[ -f "$LABELS_FILE" ]]; then
        echo "$LABELS_FILE"
    else
        echo "ERROR: labels.json not found" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Label Creation
# -----------------------------------------------------------------------------

# Create a single label (idempotent - uses --force)
# Usage: label_create "agent:planning" "1d76db" "Planning phase active"
label_create() {
    local name="$1"
    local color="$2"
    local description="$3"

    echo "Creating label: $name"
    gh label create "$name" --color "$color" --description "$description" --force
}

# Create all labels from labels.json
# Usage: label_create_all
label_create_all() {
    check_dependencies

    local labels_file
    labels_file=$(get_labels_file)

    echo "Creating labels from: $labels_file"
    echo "---"

    # Read labels and create each one
    jq -c '.labels[]' "$labels_file" | while read -r label; do
        local name color description
        name=$(echo "$label" | jq -r '.name')
        color=$(echo "$label" | jq -r '.color')
        description=$(echo "$label" | jq -r '.description')

        label_create "$name" "$color" "$description"
    done

    echo "---"
    echo "All labels created successfully!"
}

# -----------------------------------------------------------------------------
# Label Operations on Issues
# -----------------------------------------------------------------------------

# Add a label to an issue
# Usage: label_add "agent:planning" 42
label_add() {
    check_dependencies

    local label="$1"
    local issue_number="$2"

    echo "Adding label '$label' to issue #$issue_number"
    gh issue edit "$issue_number" --add-label "$label"
}

# Remove a label from an issue
# Usage: label_remove "agent:queued" 42
label_remove() {
    check_dependencies

    local label="$1"
    local issue_number="$2"

    echo "Removing label '$label' from issue #$issue_number"
    gh issue edit "$issue_number" --remove-label "$label"
}

# Replace one label with another
# Usage: label_replace "agent:planning" "agent:plan-review" 42
label_replace() {
    check_dependencies

    local old_label="$1"
    local new_label="$2"
    local issue_number="$3"

    echo "Replacing label '$old_label' with '$new_label' on issue #$issue_number"
    gh issue edit "$issue_number" --remove-label "$old_label" --add-label "$new_label"
}

# Clear all agent:* labels from an issue
# Usage: label_clear_all 42
label_clear_all() {
    check_dependencies

    local issue_number="$1"

    echo "Clearing all agent:* labels from issue #$issue_number"

    # Get current labels on the issue
    local current_labels
    current_labels=$(gh issue view "$issue_number" --json labels -q '.labels[].name')

    # Remove each agent:* label
    for label in $current_labels; do
        if [[ "$label" == agent:* ]]; then
            gh issue edit "$issue_number" --remove-label "$label"
            echo "  Removed: $label"
        fi
    done
}

# -----------------------------------------------------------------------------
# Label Queries
# -----------------------------------------------------------------------------

# List all defined labels
# Usage: label_list_defined
label_list_defined() {
    local labels_file
    labels_file=$(get_labels_file)

    echo "Defined labels in $labels_file:"
    jq -r '.labels[] | "  \(.name) - \(.description)"' "$labels_file"
}

# List labels on an issue
# Usage: label_list_issue 42
label_list_issue() {
    check_dependencies

    local issue_number="$1"

    echo "Labels on issue #$issue_number:"
    gh issue view "$issue_number" --json labels -q '.labels[].name' | while read -r label; do
        echo "  $label"
    done
}

# Check if an issue has a specific label
# Usage: if label_has "agent:planning" 42; then ... fi
label_has() {
    check_dependencies

    local label="$1"
    local issue_number="$2"

    gh issue view "$issue_number" --json labels -q ".labels[].name" | grep -q "^${label}$"
}

# -----------------------------------------------------------------------------
# Transition Functions (Common State Changes)
# -----------------------------------------------------------------------------

# Transition: Start planning phase
# Removes: agent:queued, agent:spec-created
# Adds: agent:planning
label_transition_to_planning() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:queued" \
        --remove-label "agent:spec-created" \
        --add-label "agent:planning" 2>/dev/null || \
    gh issue edit "$issue_number" --add-label "agent:planning"
}

# Transition: Plan ready for review
# Removes: agent:planning
# Adds: agent:plan-review
label_transition_plan_ready() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:planning" \
        --add-label "agent:plan-review"
}

# Transition: Start implementation
# Removes: agent:tasks-approved
# Adds: agent:implementing
label_transition_to_implementing() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:tasks-approved" \
        --add-label "agent:implementing"
}

# Transition: Intake processing started
# Removes: agent:queued
# Adds: agent:intake
label_transition_to_intake() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:queued" \
        --add-label "agent:intake" 2>/dev/null || \
    gh issue edit "$issue_number" --add-label "agent:intake"
}

# Transition: Intake needs supplement (spec validation failed)
# Removes: agent:intake
# Adds: agent:needs-supplement
label_transition_needs_supplement() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:intake" \
        --add-label "agent:needs-supplement"
}

# Transition: Re-intake from supplement (user edited issue)
# Removes: agent:needs-supplement
# Adds: agent:intake
label_transition_reintake() {
    local issue_number="$1"

    gh issue edit "$issue_number" \
        --remove-label "agent:needs-supplement" \
        --add-label "agent:intake"
}

# Transition: Intake succeeded, spec created
# Removes: agent:intake
# Adds: agent:spec-created (and optionally agent:plan-review or agent:plan-approved)
label_transition_intake_success() {
    local issue_number="$1"
    local skip_plan_review="${2:-false}"

    gh issue edit "$issue_number" \
        --remove-label "agent:intake" \
        --add-label "agent:spec-created"

    if [[ "$skip_plan_review" == "true" ]]; then
        gh issue edit "$issue_number" --add-label "agent:plan-approved"
    else
        gh issue edit "$issue_number" --add-label "agent:plan-review"
    fi
}

# Transition: Complete workflow
# Removes: all agent:* labels
# Adds: agent:complete
label_transition_to_complete() {
    local issue_number="$1"

    label_clear_all "$issue_number"
    gh issue edit "$issue_number" --add-label "agent:complete"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Label Management:"
    echo "  create-all                        Create all labels from labels.json"
    echo "  list-defined                      List all defined labels"
    echo ""
    echo "Issue Operations:"
    echo "  add <label> <issue>              Add label to issue"
    echo "  remove <label> <issue>           Remove label from issue"
    echo "  replace <old> <new> <issue>      Replace one label with another"
    echo "  clear-all <issue>                Remove all agent:* labels"
    echo "  list <issue>                     List labels on issue"
    echo "  has <label> <issue>              Check if issue has label (exit code)"
    echo ""
    echo "Transitions:"
    echo "  to-intake <issue>                Transition to intake phase"
    echo "  needs-supplement <issue>         Transition to needs-supplement"
    echo "  reintake <issue>                 Re-trigger intake from supplement"
    echo "  intake-success <issue> [skip]    Intake succeeded (skip=true skips plan review)"
    echo "  to-planning <issue>              Transition to planning phase"
    echo "  plan-ready <issue>               Transition to plan review"
    echo "  to-implementing <issue>          Transition to implementation"
    echo "  to-complete <issue>              Transition to complete"
}

# Main entry point
main() {
    case "${1:-help}" in
        create-all)
            label_create_all
            ;;
        list-defined)
            label_list_defined
            ;;
        add)
            label_add "$2" "$3"
            ;;
        remove)
            label_remove "$2" "$3"
            ;;
        replace)
            label_replace "$2" "$3" "$4"
            ;;
        clear-all)
            label_clear_all "$2"
            ;;
        list)
            label_list_issue "$2"
            ;;
        has)
            label_has "$2" "$3"
            ;;
        to-intake)
            label_transition_to_intake "$2"
            ;;
        needs-supplement)
            label_transition_needs_supplement "$2"
            ;;
        reintake)
            label_transition_reintake "$2"
            ;;
        intake-success)
            label_transition_intake_success "$2" "${3:-false}"
            ;;
        to-planning)
            label_transition_to_planning "$2"
            ;;
        plan-ready)
            label_transition_plan_ready "$2"
            ;;
        to-implementing)
            label_transition_to_implementing "$2"
            ;;
        to-complete)
            label_transition_to_complete "$2"
            ;;
        *)
            show_usage
            ;;
    esac
}

main "$@"
