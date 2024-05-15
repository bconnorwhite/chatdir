# chatdir

A CLI tool to prompt [Google Gemini](https://ai.google.dev/gemini-api) with the contents of a directory.

## Setup

[`jq`](https://jqlang.github.io/jq/) is required as a dependency:

```sh
brew install jq
```

## Usage

### API Key

Create an [API Key](https://aistudio.google.com/app/apikey) to use the Gemini API.

Then, make sure to include it as an environment variable:

```sh
GEMINI_API_KEY="your-api-key" ../path/to/chatdir.sh "What is in this directory?"
```

Or, use the `--env` flag to load the key from a `.env` file:

```sh
../path/to/chatdir.sh --env ../path/to/.env "What is in this directory?"
```

#### Aliasing

Alternatively, you can create an alias in your `.zshrc`:
```sh
# chatdir
chatdir() {
  ~/path/to/chatdir/chatdir.sh --env ~/path/to/chatdir/.env "$@"
}
```

Then, simply source your `.zshrc` or restart your terminal to apply the changes:
```
source ~/.zshrc
```

You should now be able to use the `chatdir` command from anywhere in your terminal.

### Options

By default, gitignored files are excluded from the prompt.

You can preview the files that will be included by using the `--ls` flag. Additionally, you can preview the full prompt by using the `--stdout` flag, or the curl command that will be sent to Google with the `--dry-run` flag.

```
Usage: chatdir [question] [directory]
   -e, --env <file>   Load GEMINI_API_KEY from a .env file
       --ls           List all targeted files
       --stdout       Print the generated prompt to stdout
       --dry-run      Print the curl command without executing it
   -h, --help         Show this help message
```

## Prompt Format

Each prompt uses the following format:
````````
Project Directory: /path/to/dir

Included Files:

```
/path/to/dir/file1.ext
/path/to/dir/file2.ext
```

`/path/to/dir/file1.ext`:

```````ext
file1...
```````

`/path/to/dir/file2.ext`:

```````ext
file2...
```````

---

Your question here
````````
