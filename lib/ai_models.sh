#!/bin/bash

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
                    "content": [{ "type": "text", "text": $system_prompt }]
                },
                {
                    "role": "user",
                    "content": [{ "type": "text", "text": $prompt }]
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

    echo "$response" | jq -r '.content[0].text' > "$outfile"
    cat "$outfile"
}

# Function to call GPT-4 using OpenAI API
call_openai() {
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-4",
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

    echo "$response" | jq -r '.choices[0].message.content' > "$outfile"
    cat "$outfile"
}

# Function to call the appropriate AI model
call_ai_model() {
    local ai_model="$1"
    local prompt="$2"
    local outfile="analysis.json"

    case "$ai_model" in
        openai)
            echo "Using GPT-4 (OpenAI) for analysis..."
            call_openai
            ;;
        aws)
            echo "Using Claude (AWS Bedrock) for analysis..."
            call_aws
            ;;
        claude)
            echo "Using Claude (Anthropic API) for analysis..."
            call_claude
            ;;
        *)
            echo "Error: Invalid AI model specified."
            exit 1
            ;;
    esac

    rm -f "$outfile"
}