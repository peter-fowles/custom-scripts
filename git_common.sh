#!/bin/bash

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if a repository has any commits by the specified authors
has_author_commits() {
  local repo_dir="$1"
  shift # Remove the repository directory from the argument list
  local authors_array=("$@") # Assign the remaining arguments to an array

  if [[ ${#authors_array[@]} -eq 0 ]]; then
    return 0
  fi

  for author in "${authors_array[@]}"; do
    if git -C "$repo_dir" log --author="$author" --quiet --all --format=%H | grep -q .; then
      return 0
    fi
  done

  return 1
}

# Check if a repository has a configured upstream remote
has_upstream() {
  local repo_dir="$1"
  local upstream
  upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref --quiet @{u} 2>/dev/null)
  [[ -n "$upstream" ]]
}

# Process repositories with shared find command logic
process_repos_common() {
  local root_directory="$1"
  local final_ignored_dirs=("${@:2}")
  local ignore_flags=()

  for dir in "${final_ignored_dirs[@]}"; do
    ignore_flags+=("-name" "$dir" "-prune" "-o")
  done

  local find_args=("$root_directory" "-type" "d")
  if [[ ${#ignore_flags[@]} -gt 0 ]]; then
    find_args+=("(" "${ignore_flags[@]}" -false ")")
    find_args+=("-o")
  fi
  find_args+=("-name" ".git")

  local temp_file
  temp_file=$(mktemp)
  find "${find_args[@]}" 2> >(grep -v "Permission denied" >&2) > "$temp_file"

  while read -r git_dir; do
    process_single_repo "$git_dir"
  done < "$temp_file"

  rm "$temp_file"
}

# --- NEW: General Argument and Configuration Handling ---

load_config() {
  # Path to the shared, example configuration file
  local CONF_FILE_EXAMPLE="$(dirname "$0")/default_values.conf.example"
  # Path to the local, uncommitted configuration file
  local CONF_FILE_LOCAL="$(dirname "$0")/default_values.conf"

  # Initialize temporary arrays to hold values from config files
  declare -a authors_from_local=()
  declare -a ignored_dirs_from_local=()
  declare -a authors_from_global=()
  declare -a ignored_dirs_from_global=()

  # Load local settings first
  if [[ -f "$CONF_FILE_LOCAL" ]]; then
    echo -e "${CYAN}Loading local overrides from: ${BOLD}$CONF_FILE_LOCAL${NC}"
    source <(grep -v '^declare' "$CONF_FILE_LOCAL" | sed 's/default_authors/authors_from_local/;s/default_ignored_dirs/ignored_dirs_from_local/')
  fi

  # Load global settings
  if [[ -f "$CONF_FILE_EXAMPLE" ]]; then
    echo -e "${CYAN}Loading global defaults from: ${BOLD}$CONF_FILE_EXAMPLE${NC}"
    source <(grep -v '^declare' "$CONF_FILE_EXAMPLE" | sed 's/default_authors/authors_from_global/;s/default_ignored_dirs/ignored_dirs_from_global/')
  fi

  # Merge and deduplicate the authors arrays
  declare -A unique_authors_map
  for author in "${authors_from_local[@]}" "${authors_from_global[@]}"; do
    [[ -n "$author" ]] && unique_authors_map["$author"]=1
  done
  default_authors=("${!unique_authors_map[@]}")

  # Merge and deduplicate the ignored directories arrays
  declare -A unique_ignored_dirs_map
  for dir in "${ignored_dirs_from_local[@]}" "${ignored_dirs_from_global[@]}"; do
    [[ -n "$dir" ]] && unique_ignored_dirs_map["$dir"]=1
  done
  default_ignored_dirs=("${!unique_ignored_dirs_map[@]}")
}

parse_args() {
  local script_name="${1}"
  shift
  
  local ARGS
  ARGS=$(getopt -o dqh -l help,directories,quoted --name "$script_name" -- "$@")

  eval set -- "$ARGS"

  while true; do
    case "$1" in
      -d|--directories)
        export show_directories=true
        shift
        ;;
      -q|--quoted)
        export format_quoted=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Invalid argument: $1" >&2
        usage
        ;;
    esac
  done

  # Handle positional arguments
  if [[ -n "$1" ]]; then
    export root_directory="$1"
  fi
}
