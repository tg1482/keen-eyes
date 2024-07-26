# Function to clean and format the JSON
clean_json() {
    local input="$1"
    local json_content

    # Attempt to isolate JSON content by extracting text between the outermost curly braces
    json_content=$(echo "$input" | sed -n '/^{/,/^}$/p' | sed 's/^{/{\n/' | sed 's/}$/\n}/')

    # Validate the extracted JSON
    if echo "$json_content" | jq empty >/dev/null 2>&1; then
        echo "$json_content"
    else
        echo '{"error": "Invalid JSON structure found in the input"}'
        return 1
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
    local cleaned_json="$1"
    local mode="$2"  # 'pr' or 'terminal'
    local cleaned_json=$(clean_json "$analysis")
    echo "$cleaned_json"

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