#!/bin/bash
set -e

# Function to display usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMPARE_TARGET]

Analyze code changes and provide feedback.

Options:
  -m, --model MODEL    Specify the AI model to use for analysis (default: claude)
                       Supported models: claude, openai, aws
  -b, --base BRANCH    Specify the base branch for comparison (default: main)
  -p, --prev           Compare against the previous commit
  -f, --force          Force analysis on large diffs (>15000 characters)
  -w, --workflow TYPE  Specify the analysis workflow (default: analysis)
                       Supported workflows: analysis, describe, ideas
  -h, --help           Display this help message

Compare Target:
  If not specified, compares against the specified base branch (default: main)
  'pr'                 Run in PR mode (look for existing PR and add comments)

Examples:
  $0                   Compare against main branch using Claude
  $0 -b develop -w describe   Compare against develop branch using Claude, with describe workflow
  $0 -p -w ideas             Compare against previous commit using Claude, with ideas workflow
  $0 -m openai -p            Compare against previous commit using OpenAI
  $0 -m aws pr               Run in PR mode using AWS model
  $0 --force -b staging      Compare against staging branch, force analysis on large diff

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
        -m|--model)
            AI_MODEL="$2"
            shift 2
            ;;
        -b|--base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        -p|--prev)
            PREV_COMMIT=true
            shift
            ;;
        -f|--force)
            FORCE_ANALYSIS=true
            shift
            ;;
        -w|--workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
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

# Validate AI model
case $AI_MODEL in
    claude|openai|aws) ;;
    *)
        echo "Error: Invalid AI model specified. Supported models are claude, openai, and aws."
        exit 1
        ;;
esac

case $WORKFLOW in
    analysis|describe|ideas) ;;
    *)
        echo "Error: Invalid workflow specified. Supported workflows are analysis, describe, and ideas."
        exit 1
        ;;
esac


# Function to get diff based on compare target
get_diff() {
    local target="$1"
    if [ "$PREV_COMMIT" = true ]; then
        git diff HEAD~1..HEAD
    else
        case $target in
            "")
                git diff "$BASE_BRANCH"..HEAD
                ;;
            pr)
                # Get the base branch for PR
                pr_base_branch=$(gh pr view --json baseRefName --jq .baseRefName)
                git diff "origin/$pr_base_branch...HEAD"
                ;;
            *)
                echo "Error: Invalid compare target. Use 'pr', or leave blank for comparison against $BASE_BRANCH."
                exit 1
                ;;
        esac
    fi
}

# Function to get changed files
get_changed_files() {
    local target="$1"
    if [ "$PREV_COMMIT" = true ]; then
        git diff --name-only HEAD~1..HEAD
    else
        case $target in
            "")
                git diff --name-only "$BASE_BRANCH"..HEAD
                ;;
            pr)
                # Get the base branch for PR
                pr_base_branch=$(gh pr view --json baseRefName --jq .baseRefName)
                git diff --name-only "origin/$pr_base_branch...HEAD"
                ;;
        esac
    fi
}

# Function to get commit information and change statistics
get_commit_info() {
    local target="$1"
    local base_commit
    local head_commit
    local commit_message
    local workflow
    local base_name
    
    if [ "$PREV_COMMIT" = true ]; then
        base_commit="HEAD~1"
        head_commit="HEAD"
        commit_message=$(git log -1 --pretty=%B)
        workflow="Comparing against previous commit"
        base_name="Previous commit"
    else
        case $target in
            "")
                base_commit="$BASE_BRANCH"
                head_commit="HEAD"
                commit_message=$(git log $BASE_BRANCH..HEAD --reverse --pretty=%B | head -n 1)
                workflow="Comparing current branch against $BASE_BRANCH branch"
                base_name="$BASE_BRANCH branch"
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

# Get the diff and changed files
diff_output=$(get_diff "$COMPARE_TARGET")
changed_files=$(get_changed_files "$COMPARE_TARGET")

# Get and display commit information and change statistics
commit_info=$(get_commit_info "$COMPARE_TARGET")
echo "$commit_info"

# Check the length of the diff
max_diff_length=15000
diff_length=${#diff_output}

if [ $diff_length -gt $max_diff_length ] && [ "$FORCE_ANALYSIS" = false ]; then
    echo "Error: Diff is longer than $max_diff_length characters."
    echo "To force analysis on this large diff, rerun the script with the -f or --force flag."
    exit 1
elif [ $diff_length -gt $max_diff_length ]; then
    echo "Warning: Analyzing a large diff ($diff_length characters). This may take longer and could be less accurate."
fi

system_prompt="You are an expert code reviewer who follows the best practices, loves simple and elegant code, and is always looking for ways to improve. You're a staff engineer so you don't waste people's time with useless comments but focus on high-impact changes."

# Function to get the appropriate prompt based on the workflow
get_prompt() {
    local workflow="$1"
    local diff="$2"
    local changed_files="$3"

    case $workflow in
        analysis)
            cat << EOF
Analyze the following code changes and provide a thorough critique. Here's the diff:

$diff

And here are the files that were changed:

$changed_files

Please provide a comprehensive analysis of the changes, including:
1. A detailed summary of what the changes are doing
2. Strengths of the implementation
3. Areas of improvement or potential issues wrt to the changes
4. Any security concerns related to the changes
5. Code style and best practices observations

Key instructions:
- Be thorough and detailed in your analysis.
- Provide specific examples and line references where applicable.
- Consider both the immediate impact and potential long-term effects of the changes.
- Format your response in markdown for readability.

Your response should be a JSON object with the following structure:
{
    "summary": { "content": "Detailed summary", "importance": "high" },
    "strengths": { "content": "Strengths of the implementation", "importance": "medium" },
    "improvements": { "content": "Areas of improvement", "importance": "high" },
    "security": { "content": "Security concerns", "importance": "high" },
    "style": { "content": "Code style and best practices", "importance": "medium" }
}
EOF
            ;;
        describe)
            cat << EOF
Provide a detailed description of the following code changes. Here's the diff:

$diff

And here are the files that were changed:

$changed_files

Please describe the changes in increasing complexity, suitable for sharing with peers:
1. A high-level overview of the changes
2. A more detailed explanation of each significant modification
3. The potential impact of these changes on the existing codebase
4. Any notable design decisions or trade-offs made

Key instructions:
- Start with a simple explanation and progressively add more technical details.
- Use clear, concise language that both technical and non-technical team members can understand.
- Highlight the purpose and context of the changes.
- Format your response in markdown for readability.

Your response should be a JSON object with the following structure:
{
    "overview": { "content": "High-level overview", "importance": "high" },
    "details": { "content": "Detailed explanation", "importance": "medium" },
    "impact": { "content": "Potential impact", "importance": "medium" },
    "decisions": { "content": "Notable design decisions", "importance": "low" }
}
EOF
            ;;
        ideas)
            cat << EOF
Review the following code changes and suggest ideas for improvements. Here's the diff:

$diff

And here are the files that were changed:

$changed_files

Please provide:
1. Ideas for further improvements or enhancements
2. Suggestions to fix any remaining issues or potential bugs
3. Recommendations for optimizing performance or code quality
4. Thoughts on potential features or functionality that could be added

Key instructions:
- Be creative and think beyond the immediate changes.
- Consider both small optimizations and larger architectural improvements.
- Provide rationale for your suggestions.
- Format your response in markdown for readability.

Your response should be a JSON object with the following structure:
{
    "improvements": { "content": "Ideas for further improvements", "importance": "high" },
    "bugfixes": { "content": "Suggestions to fix issues", "importance": "high" },
    "optimizations": { "content": "Recommendations for optimizing", "importance": "medium" },
    "features": { "content": "Potential new features", "importance": "low" }
}
EOF
            ;;
    esac
}


# Function to call AWS using AWS Bedrock
call_aws() {
    local body=$(jq -n \
        --arg system_prompt "$system_prompt" \
        --arg prompt "$prompt" \
        '{
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "system",
                    "content": [
                        {
                            "type": "text",
                            "text": $system_prompt
                        }
                    ]
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": $prompt
                        }
                    ]
                }
            ]
        }')

    aws bedrock-runtime invoke-model \
        --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
        --body "$body" \
        --cli-binary-format raw-in-base64-out \
        --accept "application/json" \
        --content-type "application/json" \
        "$outfile"

    jq -r '.content[0].text' "$outfile" | sed 's/```json//g' | sed 's/```//g' | jq -r '.'
}

# Function to call Claude using Anthropic API
call_claude() {
    local response=$(curl -s https://api.anthropic.com/v1/messages \
        --header "x-api-key: $ANTHROPIC_API_KEY" \
        --header "anthropic-version: 2023-06-01" \
        --header "content-type: application/json" \
        --data '{
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 4096,
            "system": "$system_prompt",
            "messages": [
                {
                    "role": "user",
                    "content": '"$(echo "$prompt" | jq -R -s '.')"'
                }
            ]
        }')

    # Extract the content
    local content=$(echo "$response" | jq -r '.content[0].text')

    # Save the content to the file
    echo "$content" > "$outfile"

    # read outfile
    # local content=$(cat "$outfile")

    # Return the content
    echo "$content"
}

# Function to call GPT-4o using OpenAI API
call_openai() {
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-4o",
            "response_format": {"type": "json_object"},
            "messages": [
                {
                    "role": "system",
                    "content": '"$(echo "$system_prompt" | jq -R -s '.')"'
                },
                {
                    "role": "user",
                    "content": '"$(echo "$prompt" | jq -R -s '.')"'
                }
            ]
        }')

    # Extract the content
    local content=$(echo "$response" | jq -r '.choices[0].message.content')

    # Save the content to the file
    echo "$content" > "$outfile"

    # Return the content
    echo "$content"
}

# outfile for temporary storage
outfile="analysis.json"

# Call the appropriate AI model and capture the output
if [ "$AI_MODEL" = "openai" ]; then
    echo "Using GPT-4o (OpenAI) for analysis..."
    analysis=$(call_openai)
elif [ "$AI_MODEL" = "aws" ]; then
    echo "Using Claude (AWS Bedrock) for analysis..."
    analysis=$(call_aws)
else
    echo "Using Claude (Anthropic API) for analysis..."
    analysis=$(call_claude)
fi

# Function to clean and format the JSON
clean_json() {
    local input="$1"
    # Remove leading and trailing whitespace
    local trimmed=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Extract JSON from markdown code block if present
    if [[ "$trimmed" == *'```json'* ]]; then
        trimmed=$(echo "$trimmed" | sed -n '/```json/,/```/p' | sed '1d;$d')
    fi
    # Check if the input is valid JSON
    if jq -e . >/dev/null 2>&1 <<<"$trimmed"; then
        echo "$trimmed"
    else
        # If not valid JSON, return an error JSON
        echo '{"error": "No valid JSON found in the input"}'
    fi
}

# Function to safely get a value from JSON
safe_get_json_value() {
    local json="$1"
    local key="$2"
    local default="$3"
    local value=$(echo "$json" | jq -r ".$key.content // \"$default\"" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}


# Function to format the analysis output, preserving JSON order
format_analysis_output() {
    local cleaned_json="$1"
    local formatted_output="# Code Analysis Summary\n\n"

    # Use jq to iterate over the keys in their original order
    while IFS= read -r entry; do
        local section=$(echo "$entry" | jq -r '.key')
        local importance=$(echo "$entry" | jq -r '.value.importance // "low"')
        local content=$(echo "$entry" | jq -r '.value.content // ""')

        if [ "$importance" != "low" ] && [ -n "$content" ]; then
            local title=$(echo "$section" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
            formatted_output+="## ${title} \n"
            formatted_output+="Importance: ${importance}\n\n"
            
            # Process content: Add proper list formatting and code blocks
            # content=$(echo "$content" | sed 's/^[0-9]\+\. /\n&/g')  # Ensure numbers start on new lines
            # content=$(echo "$content" | sed 's/`\([^`]*\)`/`\1`/g')  # Ensure inline code is properly formatted
            # content=$(echo "$content" | sed 's/\([a-zA-Z_][a-zA-Z0-9_]*\.py\)/`\1`/g')  # Format .py files as code
            # content=$(echo "$content" | sed 's/\([a-zA-Z_][a-zA-Z0-9_]*(\)/`\1`/g')  # Format function names as code
            
            formatted_output+="${content}\n\n"
        fi
    done < <(echo "$cleaned_json" | jq -c 'to_entries[]')

    echo -e "$formatted_output"
}

# Function to add a single comment to the PR
add_pr_comment() {
    local content="$1"
    gh pr comment "$pr_number" --body "$content"
}

# Function to parse and output the analysis
parse_and_output() {
    local analysis="$1"
    local mode="$2"  # 'pr' or 'terminal'
    local cleaned_json=$(clean_json "$analysis")

    # Check if the cleaned JSON indicates an error
    if [[ $(echo "$cleaned_json" | jq -r '.error // empty') ]]; then
        echo "Error: Failed to parse AI analysis output."
        echo "Raw output:"
        echo "$analysis"
        return
    fi

    local formatted_output=$(format_analysis_output "$cleaned_json")

    if [ -z "$(echo -e "$formatted_output" | sed -e '/^$/d' -e '/^# Code Analysis Summary$/d')" ]; then
        formatted_output+="No high or medium importance items found in the analysis.\n"
    fi

    if [ "$mode" = "pr" ]; then
        add_pr_comment "$formatted_output"
        echo "Analysis added as a single comment to PR #$pr_number"
    else
        echo -e "$formatted_output"
    fi
}

# Main execution logic
echo "Executing workflow for $WORKFLOW"
prompt=$(get_prompt "$WORKFLOW" "$diff_output" "$changed_files")
analysis=$(call_${AI_MODEL})

if [ "$COMPARE_TARGET" = "pr" ]; then
    parse_and_output "$analysis" "pr"
    echo "Analysis added as a single comment to PR #$pr_number"
else
    parse_and_output "$analysis" "terminal"
fi

# Clean up
# rm -f "$outfile"