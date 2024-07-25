#!/bin/bash

# Function to get diff based on compare target
get_diff() {
    local target="$1"
    local prev_commit="$2"
    local base_branch="$3"

    if [ "$prev_commit" = true ]; then
        git diff HEAD~1..HEAD
    else
        case $target in
            "")
                git diff "$base_branch"..HEAD
                ;;
            pr)
                pr_base_branch=$(gh pr view --json baseRefName --jq .baseRefName)
                git diff "origin/$pr_base_branch...HEAD"
                ;;
            *)
                echo "Error: Invalid compare target. Use 'pr', or leave blank for comparison against $base_branch."
                exit 1
                ;;
        esac
    fi
}

# Function to get changed files
get_changed_files() {
    local target="$1"
    local prev_commit="$2"
    local base_branch="$3"

    if [ "$prev_commit" = true ]; then
        git diff --name-only HEAD~1..HEAD
    else
        case $target in
            "")
                git diff --name-only "$base_branch"..HEAD
                ;;
            pr)
                pr_base_branch=$(gh pr view --json baseRefName --jq .baseRefName)
                git diff --name-only "origin/$pr_base_branch...HEAD"
                ;;
        esac
    fi
}

# Function to get commit information and change statistics
get_commit_info() {
    local target="$1"
    local prev_commit="$2"
    local base_branch="$3"
    local base_commit
    local head_commit
    local commit_message
    local workflow
    local base_name
    
    if [ "$prev_commit" = true ]; then
        base_commit="HEAD~1"
        head_commit="HEAD"
        commit_message=$(git log -1 --pretty=%B)
        workflow="Comparing against previous commit"
        base_name="Previous commit"
    else
        case $target in
            "")
                base_commit="$base_branch"
                head_commit="HEAD"
                commit_message=$(git log $base_branch..HEAD --reverse --pretty=%B | head -n 1)
                workflow="Comparing current branch against $base_branch branch"
                base_name="$base_branch branch"
                ;;
            pr)
                pr_base_branch=$(gh pr view --json baseRefName --jq .baseRefName)
                base_commit="origin/$pr_base_branch"
                head_commit="HEAD"
                commit_message=$(git log $base_commit..$head_commit --reverse --pretty=%B | head -n 1)
                workflow="Running in PR mode"
                base_name="$pr_base_branch branch"
                ;;
        esac
    fi

    local base_short=$(git rev-parse --short $base_commit)
    local head_short=$(git rev-parse --short $head_commit)
    local num_files=$(git diff --name-only $base_commit $head_commit | wc -l)
    local num_changes=$(git diff --numstat $base_commit $head_commit | awk '{added+=$1; deleted+=$2} END {print added+deleted}')
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    cat << EOF
Workflow Triggered: $workflow

Comparison Information:
-----------------------
$base_name: $base_short
Current branch ($current_branch): $head_short
Commit Message: $commit_message

Changes:
- Files changed: $num_files
- Lines changed: $num_changes (additions + deletions)

EOF
}

# Function to check the length of the diff
check_diff_length() {
    local diff_output="$1"
    local force_analysis="$2"
    local max_diff_length=15000
    local diff_length=${#diff_output}

    if [ $diff_length -gt $max_diff_length ] && [ "$force_analysis" = false ]; then
        echo "Error: Diff is longer than $max_diff_length characters."
        echo "To force analysis on this large diff, rerun the script with the -f or --force flag."
        exit 1
    elif [ $diff_length -gt $max_diff_length ]; then
        echo "Warning: Analyzing a large diff ($diff_length characters). This may take longer and could be less accurate."
    fi
}