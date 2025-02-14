#/bin/zsh

help=false
env_file=""
model="gemini-2.0-flash"
ls=false
stdout=false
dry_run=false
tokens=false
dir=""
question=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      help=true
      ;;
    --env|-e)
      shift
      env_file="$1"
      ;;
    --pro)
      model="gemini-1.5-pro"
      ;;
    --model|-m)
      shift
      model="$1"
      ;;
    --ls)
      ls=true
      ;;
    --stdout)
      stdout=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    --tokens)
      tokens=true
      ;;
    *)
      if [ -z "$question" ]; then
        question="$1"
      elif [ -z "$dir" ]; then
        # If we already have a question, shift the question to the directory and take the second argument as the question
        dir="$(realpath "$question")"
        question="$1"
      else
        echo "Error: Too many arguments."
        help
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -n "$env_file" ]; then
  if [ -f "$env_file" ]; then
    source "$env_file"
  else
    echo "Error: .env file '$env_file' not found."
    exit 1
  fi
fi

if [ -z "$dir" ]; then
  dir="$(pwd)"
fi

help() {
  echo "Usage: chatdir [directory] <question>"
  echo "   -e, --env <file>   Load GEMINI_API_KEY from a .env file"
  echo "   -m, --model <name> Use the specified model (default: gemini-2.0-flash)"
  echo "       --pro          Use the gemini-1.5-pro model"
  echo "       --ls           List all targeted files"
  echo "       --stdout       Print the generated prompt to stdout"
  echo "       --tokens       Count the tokens in the generated prompt without prompting the model"
  echo "       --dry-run      Print the resulting curl command without executing it"
  echo "   -h, --help         Show this help message"
}

list_files() {
  local dir="$1"
  git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  if [ $? -eq 0 ]; then
    git -C "$git_root" ls-files --exclude-standard | while read -r file; do
      echo "$git_root/$file"
    done | grep "^$dir/"
  else
    find "$dir" -type f
  fi
}

ext() {
  local file="$1"
  local filename=$(basename -- "$file")
  local extension="${filename##*.}"
  if [ "$filename" = "$extension" ]; then
    echo "$filename"
  else
    echo "$extension"
  fi
}

format() {
  local file="$1"
  local extension=$(ext "$file")
  echo "\`$file\`:"
  echo ""
  echo '```````'"$extension"
  cat "$file"
  echo '```````'
}

context() {
  local dir="$1"
  local files=$(list_files "$dir")
  echo "Project Directory: $dir"
  echo "\nIncluded Files:\n\n\`\`\`"
  echo "$files"
  echo "\`\`\`\n"
  for file in $files; do
    format "$file"
    echo ""
  done
}

prompt() {
  local dir="$1"
  local question="$2"
  context "$dir"
  echo -n "---\n\n$question"
}

json_body() {
  local dir="$1"
  local questions="$2"
  prompt "$dir" "$questions" \
    | jq --raw-input --slurp --compact-output --monochrome-output -j '{"contents": [{"parts": [{"text": .}] } ] }'
}

if $help; then
  help
  exit 0
fi

if $ls; then
  list_files "$dir"
  exit 0
fi

if [ -z "$GEMINI_API_KEY" ]; then
  echo "Error: GEMINI_API_KEY environment variable is not set."
  exit 1
fi

if [ -z "$question" ] && ! $tokens; then
  echo "Error: No question provided."
  help
  exit 1
fi

if $stdout; then
  json_body "$dir" "$question"
elif $tokens; then
  API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/$model:countTokens?key=$GEMINI_API_KEY"
  if $dry_run; then
    echo "curl \\"
    echo "  --silent \\"
    echo "  -H "Content-Type: application/json" \\"
    echo "  -X POST \"$API_ENDPOINT\" \\"
    printf "  -d '"
    json_body "$dir" "$question"
    echo "'"
  else
    json_body "$dir" "$question" \
      | curl --silent -H "Content-Type: application/json" -X POST "$API_ENDPOINT" -d @- \
      | jq -r '.totalTokens'
  fi
else
  API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$GEMINI_API_KEY"
  if $dry_run; then
    echo "curl \\"
    echo "  --silent \\"
    echo "  -H "Content-Type: application/json" \\"
    echo "  -X POST \"$API_ENDPOINT\" \\"
    printf "  -d '"
    json_body "$dir" "$question"
    echo "'"
  else
    json_body "$dir" "$question" \
      | curl --silent -H "Content-Type: application/json" -X POST "$API_ENDPOINT" -d @- \
      | jq -r '.candidates[0].content.parts[0].text'
  fi
fi
