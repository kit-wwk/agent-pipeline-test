#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# =============================================================================
# State Manager - Agent Pipeline State Management
# =============================================================================
# Manages workflow state for the Agent pipeline using JSON files.
# State is stored in .agent/state/<feature-id>/workflow-state.json
#
# Usage:
#   source state-manager.sh
#   state_init "001-my-feature" 42
#   state_set_phase "planning"
#   current_phase=$(state_get_phase)
#
# Dependencies: jq
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
STATE_DIR="${STATE_DIR:-.agent/state}"
STATE_VERSION="1.0.0"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Get the state file path for a feature
# Usage: state_file_path "001-my-feature"
state_file_path() {
    local feature_id="$1"
    echo "${STATE_DIR}/${feature_id}/workflow-state.json"
}

# Check if jq is available
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required but not installed." >&2
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# State Initialization
# -----------------------------------------------------------------------------

# Initialize state for a new feature
# Usage: state_init "001-my-feature" 42
state_init() {
    check_jq
    local feature_id="$1"
    local issue_number="$2"
    local state_file
    state_file=$(state_file_path "$feature_id")
    local state_dir
    state_dir=$(dirname "$state_file")

    # Create state directory if it doesn't exist
    mkdir -p "$state_dir"

    # Check if state already exists
    if [[ -f "$state_file" ]]; then
        echo "State already exists for feature: $feature_id" >&2
        return 1
    fi

    # Create initial state
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq -n \
        --arg version "$STATE_VERSION" \
        --arg feature_id "$feature_id" \
        --argjson issue_number "$issue_number" \
        --arg created_at "$now" \
        --arg updated_at "$now" \
        '{
            version: $version,
            feature_id: $feature_id,
            issue_number: $issue_number,
            phase: "queued",
            phase_state: "initialized",
            created_at: $created_at,
            updated_at: $updated_at,
            history: [{
                phase: "queued",
                state: "initialized",
                timestamp: $created_at,
                actor: "bot"
            }],
            task_progress: null,
            qa_results: null,
            pr_number: null,
            error: null
        }' > "$state_file"

    echo "State initialized for feature: $feature_id"
}

# -----------------------------------------------------------------------------
# State Reading
# -----------------------------------------------------------------------------

# Load state for a feature (outputs JSON)
# Usage: state_load "001-my-feature"
state_load() {
    check_jq
    local feature_id="$1"
    local state_file
    state_file=$(state_file_path "$feature_id")

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR: No state found for feature: $feature_id" >&2
        return 1
    fi

    cat "$state_file"
}

# Get current phase
# Usage: phase=$(state_get_phase "001-my-feature")
state_get_phase() {
    local feature_id="$1"
    state_load "$feature_id" | jq -r '.phase'
}

# Get current phase state
# Usage: phase_state=$(state_get_phase_state "001-my-feature")
state_get_phase_state() {
    local feature_id="$1"
    state_load "$feature_id" | jq -r '.phase_state'
}

# Get issue number
# Usage: issue=$(state_get_issue "001-my-feature")
state_get_issue() {
    local feature_id="$1"
    state_load "$feature_id" | jq -r '.issue_number'
}

# Get task progress
# Usage: progress=$(state_get_task_progress "001-my-feature")
state_get_task_progress() {
    local feature_id="$1"
    state_load "$feature_id" | jq '.task_progress'
}

# -----------------------------------------------------------------------------
# State Writing
# -----------------------------------------------------------------------------

# Update state file with new values
# Usage: state_update "001-my-feature" '.phase = "planning"'
state_update() {
    check_jq
    local feature_id="$1"
    local jq_filter="$2"
    local state_file
    state_file=$(state_file_path "$feature_id")

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR: No state found for feature: $feature_id" >&2
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update state with timestamp
    local temp_file
    temp_file=$(mktemp)
    jq "$jq_filter | .updated_at = \"$now\"" "$state_file" > "$temp_file"
    mv "$temp_file" "$state_file"
}

# Set current phase and record in history
# Usage: state_set_phase "001-my-feature" "planning" "started"
state_set_phase() {
    local feature_id="$1"
    local phase="$2"
    local phase_state="${3:-active}"
    local actor="${4:-bot}"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    state_update "$feature_id" \
        --arg phase "$phase" \
        --arg phase_state "$phase_state" \
        --arg actor "$actor" \
        --arg timestamp "$now" \
        '.phase = $phase | .phase_state = $phase_state | .history += [{phase: $phase, state: $phase_state, timestamp: $timestamp, actor: $actor}]'
}

# Update task progress
# Usage: state_set_task_progress "001-my-feature" 12 5 "T006"
state_set_task_progress() {
    local feature_id="$1"
    local total="$2"
    local completed="$3"
    local current="$4"

    state_update "$feature_id" \
        --argjson total "$total" \
        --argjson completed "$completed" \
        --arg current "$current" \
        '.task_progress = {total: $total, completed: $completed, current: $current, blocked: []}'
}

# Set error information
# Usage: state_set_error "001-my-feature" "Task failed" "T005" 2
state_set_error() {
    local feature_id="$1"
    local message="$2"
    local step="$3"
    local retry_count="${4:-0}"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    state_update "$feature_id" \
        --arg message "$message" \
        --arg step "$step" \
        --argjson retry_count "$retry_count" \
        --arg timestamp "$now" \
        '.error = {message: $message, step: $step, retry_count: $retry_count, timestamp: $timestamp}'
}

# Clear error
# Usage: state_clear_error "001-my-feature"
state_clear_error() {
    local feature_id="$1"
    state_update "$feature_id" '.error = null'
}

# Set PR number
# Usage: state_set_pr "001-my-feature" 123
state_set_pr() {
    local feature_id="$1"
    local pr_number="$2"
    state_update "$feature_id" --argjson pr_number "$pr_number" '.pr_number = $pr_number'
}

# -----------------------------------------------------------------------------
# State Validation
# -----------------------------------------------------------------------------

# Validate state file structure
# Usage: state_validate "001-my-feature"
state_validate() {
    check_jq
    local feature_id="$1"
    local state_file
    state_file=$(state_file_path "$feature_id")

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR: No state found for feature: $feature_id" >&2
        return 1
    fi

    # Check required fields
    local required_fields=("version" "feature_id" "issue_number" "phase" "created_at" "updated_at")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$state_file" > /dev/null 2>&1; then
            echo "ERROR: Missing required field: $field" >&2
            return 1
        fi
    done

    # Validate phase is a known value
    local phase
    phase=$(jq -r '.phase' "$state_file")
    local valid_phases=("queued" "intake" "spec" "planning" "tasks" "implementing" "qa" "pr" "complete")
    local valid=false
    for valid_phase in "${valid_phases[@]}"; do
        if [[ "$phase" == "$valid_phase" ]]; then
            valid=true
            break
        fi
    done

    if [[ "$valid" != "true" ]]; then
        echo "ERROR: Invalid phase: $phase" >&2
        return 1
    fi

    echo "State validation passed for: $feature_id"
    return 0
}

# -----------------------------------------------------------------------------
# State Listing
# -----------------------------------------------------------------------------

# List all feature states
# Usage: state_list
state_list() {
    check_jq

    if [[ ! -d "$STATE_DIR" ]]; then
        echo "No state directory found"
        return 0
    fi

    for state_file in "$STATE_DIR"/*/workflow-state.json; do
        if [[ -f "$state_file" ]]; then
            local feature_id phase issue
            feature_id=$(jq -r '.feature_id' "$state_file")
            phase=$(jq -r '.phase' "$state_file")
            issue=$(jq -r '.issue_number' "$state_file")
            echo "$feature_id (Issue #$issue): $phase"
        fi
    done
}

# -----------------------------------------------------------------------------
# Main (for testing)
# -----------------------------------------------------------------------------

# If script is run directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        init)
            state_init "$2" "$3"
            ;;
        load)
            state_load "$2"
            ;;
        phase)
            state_get_phase "$2"
            ;;
        set-phase)
            state_set_phase "$2" "$3" "${4:-active}"
            ;;
        validate)
            state_validate "$2"
            ;;
        list)
            state_list
            ;;
        *)
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Commands:"
            echo "  init <feature-id> <issue-number>  Initialize state for a feature"
            echo "  load <feature-id>                 Load and display state"
            echo "  phase <feature-id>                Get current phase"
            echo "  set-phase <feature-id> <phase>    Set current phase"
            echo "  validate <feature-id>             Validate state structure"
            echo "  list                              List all feature states"
            ;;
    esac
fi
