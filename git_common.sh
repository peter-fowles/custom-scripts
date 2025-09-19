#!/bin/bash

# --- Shared Utility Functions ---

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
# Takes the root directory and the final ignored directories array
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

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
