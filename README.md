# Keen Eyes: AI-Powered Code Review Tool

Keen Eyes is a lightweight, powerful command-line tool that leverages AI to provide insightful code reviews. It analyzes your code changes and offers valuable feedback, helping you improve code quality and catch potential issues before they make it to production.

![Keen Eyes Demo](./public/keen-eyes.gif)

## Features

- **Multiple AI Models**: Choose between Claude (Anthropic), GPT-4 (OpenAI), or Claude on AWS Bedrock for your code analysis.
- **Flexible Workflows**: Select from three different analysis workflows to suit your needs:
  - **Analysis**: Comprehensive code review with detailed feedback.
  - **Describe**: Clear explanation of code changes for team communication.
  - **Ideas**: Creative suggestions for further improvements and optimizations.
- **Git Integration**: Seamlessly compare changes against different branches or commits.
- **PR Mode**: Automatically add AI-generated comments to your Pull Requests.
- **Customizable**: Easy to extend with new AI models or workflows.

## Installation

1. Clone the repository:

   ```
   git clone https://github.com/tg1482/keen-eyes.git
   cd keen-eyes
   ```

2. Run the setup script:

   ```
   ./setup.sh
   ```

   This script will install Keen Eyes in your home directory and create a symlink in `/usr/local/bin`.

3. If the installation is successful, you can use the `keen-eyes` command from anywhere in your terminal.

4. If you see a warning that the command is not found in the PATH, you may need to add `/usr/local/bin` to your PATH or restart your terminal.

## Usage

After installation, you can use Keen Eyes from anywhere in your terminal:

```
keen-eyes [OPTIONS] [COMPARE_TARGET]
```

For full usage instructions, run:

```
keen-eyes --help
```

### Options

- `-m, --model MODEL`: Specify the AI model (claude, openai, aws)
- `-b, --base BRANCH`: Specify the base branch for comparison (default: main)
- `-p, --prev`: Compare against the previous commit
- `-f, --force`: Force analysis on large diffs (>15000 characters)
- `-w, --workflow TYPE`: Specify the analysis workflow (analysis: `anal`, describe: `desc`, ideas: `ideas`)
- `-h, --help`: Display help message

### Examples

1. Compare current branch against main using Claude:

   ```
   keen-eyes
   ```

2. Compare against develop branch using Claude, with describe workflow:

   ```
   keen-eyes -b develop -w desc
   ```

3. Compare against previous commit using Claude, with ideas workflow:

   ```
   keen-eyes -p -w ideas
   ```

4. Compare against previous commit using OpenAI:

   ```
   keen-eyes -m openai -p
   ```

5. Run in PR mode using AWS model:
   ```
   keen-eyes -m aws pr
   ```

## Project Structure

```
keen-eyes/
├── bin/
│   └── keen-eyes
├── lib/
│   ├── ai_models.sh
│   ├── diff_utils.sh
│   ├── formatters.sh
│   └── workflows.sh
├── setup.sh
├── uninstall.sh
└── README.md
```

- `bin/keen-eyes`: Main executable script
- `lib/`: Contains modular functionality
  - `ai_models.sh`: Functions for different AI models
  - `diff_utils.sh`: Git diff and file change utilities
  - `formatters.sh`: Output formatting functions
  - `workflows.sh`: Different analysis workflow implementations
- `setup.sh`: Installation script
- `uninstall.sh`: Uninstallation script

## Configuration

Keen Eyes uses environment variables for API keys:

- `ANTHROPIC_API_KEY`: For Claude (Anthropic) API
- `OPENAI_API_KEY`: For GPT-4 (OpenAI) API
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: For AWS Bedrock

Set these in your `.bashrc` or `.zshrc` file:

```
export ANTHROPIC_API_KEY="your_api_key_here"
export OPENAI_API_KEY="your_api_key_here"
export AWS_ACCESS_KEY_ID="your_aws_access_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_key"
```

## Extending Keen Eyes

### Adding New AI Models

1. Add a new function in `lib/ai_models.sh`.
2. Update the `call_ai_model` function in `lib/ai_models.sh`.
3. Add the new model to the validation in `lib/workflows.sh`.

### Adding New Workflows

1. Add a new case in the `get_prompt` function in `lib/workflows.sh`.
2. Update the validation in `lib/workflows.sh`.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
