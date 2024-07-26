#!/bin/bash

# System prompt for AI models
system_prompt="You are an expert code reviewer who follows the best practices, loves simple and elegant code, and is always looking for ways to improve. You're a staff engineer so you don't waste people's time with useless comments but focus on high-impact changes."

# Function to get the appropriate prompt based on the workflow
get_prompt() {
    local workflow="$1"
    local diff="$2"
    local changed_files="$3"

    case $workflow in
        anal)
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
- Format your response in markdown for readability. If you need to break lines, use "\\n"

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
        desc)
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
- Format your response in markdown for readability. If you need to break lines, use "\\n"

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
- Format your response in markdown for readability. If you need to break lines, use "\\n"

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

# Function to validate inputs
validate_inputs() {
    local ai_model="$1"
    local workflow="$2"

    case $ai_model in
        claude|openai|aws|ollama) ;;
        *)
            echo "Error: Invalid AI model specified. Supported models are claude, openai, aws, and ollama."
            exit 1
            ;;
    esac

    case $workflow in
        anal|desc|ideas) ;;
        *)
            echo "Error: Invalid workflow specified. Supported workflows are anal, desc, and ideas."
            exit 1
            ;;
    esac
}