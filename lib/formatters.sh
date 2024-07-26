# Function to clean and format the JSON or return the full content as a string
clean_json() {
    local input="$1"
    local json_content

    # Attempt to isolate JSON content by extracting text between the outermost curly braces
    json_content=$(echo "$input" | sed -n '/^{/,/^}$/p' | sed 's/^{/{\n/' | sed 's/}$/\n}/')

    # Validate the extracted JSON
    if [ -n "$json_content" ] && echo "$json_content" | jq empty >/dev/null 2>&1; then 
        # Valid non-empty JSON found, return it
        echo "$json_content"
    else
        # No valid JSON found or empty result, return the full input as a string
        echo "$input"
    fi
}

# Function to safely process jq output
safe_jq() {
    local input="$1"
    local query="$2"
    local result

    result=$(echo "$input" | jq -r "$query" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: jq processing failed"
    else
        echo "$result"
    fi
}

# Function to format the analysis output
format_analysis_output() {
    local cleaned_content="$1"
    local formatted_output=""

    # Check if the content is valid JSON
    if echo "$cleaned_content" | jq empty >/dev/null 2>&1; then
        # It's JSON, so parse and format it
        formatted_output="# Code Analysis Summary\n\n"
        while IFS= read -r entry; do
            local section=$(safe_jq "$entry" '.key')
            local importance=$(safe_jq "$entry" '.value.importance // "low"')
            local content=$(safe_jq "$entry" '.value.content // ""')

            if [ "$section" = "ERROR: jq processing failed" ] || 
               [ "$importance" = "ERROR: jq processing failed" ] || 
               [ "$content" = "ERROR: jq processing failed" ]; then
                formatted_output+="Error processing JSON entry. Raw entry: $entry\n\n"
            elif [ "$importance" = "high" ] || [ "$importance" = "medium" ]; then
                local title=$(echo "$section" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
                formatted_output+="## ${title} \n"
                formatted_output+="Importance: ${importance}\n\n"
                formatted_output+="${content}\n\n"
            fi
        done < <(echo "$cleaned_content" | jq -c 'to_entries[]' 2>/dev/null || echo '[]')
    else
        # It's not JSON, so just return the full content as is
        formatted_output="$cleaned_content"
    fi

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
    
    local cleaned_content=$(clean_json "$analysis")
    local formatted_output=$(format_analysis_output "$cleaned_content")

    if echo "$cleaned_content" | jq empty >/dev/null 2>&1; then
        # Valid JSON case
        if [ -z "$(echo -e "$formatted_output" | sed -e '/^$/d' -e '/^# Code Analysis Summary$/d')" ]; then
            formatted_output+="No high or medium importance items found in the analysis.\n"
        fi
    else
        # Non-JSON case
        formatted_output="$cleaned_content"
    fi

    if [ "$mode" = "pr" ]; then
        add_pr_comment "$formatted_output"
        echo "Analysis added as a single comment to PR #$pr_number"
    else
        echo -e "$formatted_output"
    fi
}