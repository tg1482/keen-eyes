#!/bin/bash
set -e

# Source library files
source "$(dirname "$0")/../lib/ai_models.sh"
source "$(dirname "$0")/../lib/diff_utils.sh"
source "$(dirname "$0")/../lib/formatters.sh"
source "$(dirname "$0")/../lib/workflows.sh"

# Function to display usage information
usage() {
    cat << EOF
Usage: keen-eyes [OPTIONS] [COMPARE_TARGET]

Analyze code changes and provide feedback.

Options:
  -m, --model MODEL    Specify the AI model to use for analysis (default: claude)
                       Supported models: claude, openai, aws, ollama
  -b, --base BRANCH    Specify the base branch for comparison (default: main)
  -p, --prev           Compare against the previous commit
  -f, --force          Force analysis on large diffs (>15000 characters)
  -w, --workflow TYPE  Specify the analysis workflow (default: analysis)
                       Supported workflows: analysis/anal, describe/desc, ideas
  -h, --help           Display this help message

Compare Target:
  If not specified, compares against the specified base branch (default: main)
  'pr'                 Run in PR mode (look for existing PR and add comments)

Examples:
  keen-eyes                   Compare against main branch using Claude
  keen-eyes -b develop -w describe   Compare against develop branch using Claude, with describe workflow
  keen-eyes -p -w ideas             Compare against previous commit using Claude, with ideas workflow
  keen-eyes -m openai -p            Compare against previous commit using OpenAI
  keen-eyes -m aws pr               Run in PR mode using AWS model
  keen-eyes --force -b staging      Compare against staging branch, force analysis on large diff

EOF
    exit 1
}

# Parse command-line arguments
AI_MODEL="claude"
FORCE_ANALYSIS=false
COMPARE_TARGET=""
BASE_BRANCH="main"
PREV_COMMIT=false
WORKFLOW="analysis"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--model) AI_MODEL="$2"; shift 2 ;;
        -b|--base) BASE_BRANCH="$2"; shift 2 ;;
        -p|--prev) PREV_COMMIT=true; shift ;;
        -f|--force) FORCE_ANALYSIS=true; shift ;;
        -w|--workflow) 
            case "$2" in
                anal|analysis) WORKFLOW="analysis" ;;
                desc|describe) WORKFLOW="describe" ;;
                ideas) WORKFLOW="ideas" ;;
                *)
                    echo "Error: Invalid workflow type '$2'"
                    usage
                    ;;
            esac
            shift 2 ;;
        -h|--help) usage ;;
        *) 
            if [ -z "$COMPARE_TARGET" ]; then
                COMPARE_TARGET="$1"
            else
                echo "Error: Unexpected argument $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate inputs
validate_inputs "$AI_MODEL" "$WORKFLOW"

# Check for API keys
if [ "$AI_MODEL" = "claude" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY not found. Please set this environment variable."
    exit 1
elif [ "$AI_MODEL" = "openai" ] && [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY not found. Please set this environment variable."
    exit 1
elif [ "$AI_MODEL" = "aws" ] && { [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; }; then
    echo "Error: AWS_ACCESS_KEY_ID and/or AWS_SECRET_ACCESS_KEY not found. Please set these environment variables."
    exit 1
fi

# Get the diff and changed files
diff_output=$(get_diff "$COMPARE_TARGET" "$PREV_COMMIT" "$BASE_BRANCH")
changed_files=$(get_changed_files "$COMPARE_TARGET" "$PREV_COMMIT" "$BASE_BRANCH")

# Get and display commit information and change statistics
commit_info=$(get_commit_info "$COMPARE_TARGET" "$PREV_COMMIT" "$BASE_BRANCH")
echo "$commit_info"

# Check the length of the diff
check_diff_length "$diff_output" "$FORCE_ANALYSIS"

# Get the appropriate prompt based on the workflow
prompt=$(get_prompt "$WORKFLOW" "$diff_output" "$changed_files")

# Call the appropriate AI model and capture the output
analysis=$(call_ai_model "$AI_MODEL" "$prompt")

# Parse and output the analysis
if [ "$COMPARE_TARGET" = "pr" ]; then
    parse_and_output "$analysis" "pr"
else
    parse_and_output "$analysis" "terminal"
fi