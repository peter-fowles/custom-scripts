#!/bin/bash

# ==============================================================================
# git_authored_dirs - A script to list directories contributed to by default authors.
#
# Features:
#   - Lists directories of Git repositories that have commits from any author
#     defined in `default_values.conf` or `default_values.conf.example`.
#   - Does not ignore any directories during the search.
#   - Robust error handling for invalid arguments.
#   - Color-coded output for improved readability.
#
# Usage:
#   git_authored_dirs [<directory>] [-h]
#
# Examples:
#   # List directories contributed to by default authors in the current directory
#   git_authored_dirs
#
#   # List directories in a specific directory
#   git_authored_dirs ~/projects
#
# ==============================================================================

# Fix for "fatal: not a git repository" errors across filesystems.
export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

# Source common functions and definitions
source "$(dirname "$0")/git_common.sh"

# --- Configuration ---
# Variables are populated by load_config
declare -a default_authors=()
declare -a default_ignored_dirs=()
declare -a authored_directories=()

# --- Argument Parsing ---
# Variables are populated by parse_args
root_directory="$(pwd)"
user_ignored_dirs=""
is_list_mode=false
is_verbose_list=false
user_authors=""

usage() {
  echo -e "${BOLD}Usage:${NC} $0 [<directory>] [-h]"
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  <directory>               Optional. The root directory to start searching for Git repos."
  echo "                            Defaults to the current working directory."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -h                        Display this help message and exit."
  exit 1
}

# --- Core Script Logic ---

process_single_repo() {
  local git_dir="$1"
  local repo_dir
  repo_dir=$(dirname "$git_dir")

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  # Check if any default authors have commits in this repo
  if has_author_commits "$repo_dir" "${default_authors[@]}"; then
    authored_directories+=("$repo_dir")
  fi
}

# --- Execute ---

# Load configuration and parse arguments
load_config
parse_args "$0" "" "" "$@"

if [[ ! -d "$root_directory" ]]; then
  echo -e "${RED}Error:${NC} The specified directory '${BOLD}$root_directory${NC}' does not exist." >&2
  exit 1
fi

echo -e "${BOLD}Finding directories contributed to by default authors in '${CYAN}$root_directory${NC}'...${NC}"

if [[ ${#default_authors[@]} -eq 0 ]]; then
  echo -e "${YELLOW}Warning:${NC} No default authors defined. Cannot filter repositories."
  echo -e "\n${BOLD}Finished git_authored_dirs.${NC}"
  exit 0
fi

echo -e "Filtering by authors: ${CYAN}${default_authors[*]}.${NC}"
echo ""

# Process repositories without using the ignore list
process_repos_common "$root_directory" ""

if [[ ${#authored_directories[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No directories found with commits from the specified authors.${NC}"
else
  echo -e "${BOLD}--- Directories with commits by default authors:${NC}"
  printf "%s\n" "${authored_directories[@]}" | sort -u | sed 's/^/  /'
fi

echo -e "\n${BOLD}Finished git_authored_dirs.${NC}"
