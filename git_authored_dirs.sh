#!/bin/bash

# ==============================================================================
# git_authored_dirs - A script to list directories contributed to by default authors.
#
# Features:
#   - Lists directories of Git repositories that have commits from any author
#     defined in `default_values.conf`.
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

# File to load default settings from
CONF_FILE="$(dirname "$0")/default_values.conf"

# Initialize variables to be populated from the config file or defaults
declare -a default_authors=()
declare -a default_ignored_dirs=()
declare -a authored_directories=()

# Load settings from the config file if it exists
if [[ -f "$CONF_FILE" ]]; then
  echo -e "${CYAN}Loading configuration from: ${BOLD}$CONF_FILE${NC}"
  source "$CONF_FILE"
else
  echo -e "${YELLOW}Warning:${NC} No configuration file found at '$CONF_FILE'. Using empty defaults." >&2
fi

# --- Argument Parsing ---

root_directory="$(pwd)"

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

# Parse command-line arguments and validate
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h)
      usage
      ;;
    -*)
      echo -e "${RED}Invalid option:${NC} $1" >&2
      usage
      ;;
    *)
      if [[ "$root_directory" != "$(pwd)" ]]; then
        echo -e "${RED}Error:${NC} Cannot specify multiple directories. Already set to '${BOLD}$root_directory${NC}'." >&2
        usage
      fi
      root_directory="$1"
      ;;
  esac
  shift
done

# --- Core Script Logic ---

if [[ ! -d "$root_directory" ]]; then
  echo -e "${RED}Error:${NC} The specified directory '${BOLD}$root_directory${NC}' does not exist." >&2
  exit 1
fi

process_single_repo() {
  local git_dir="$1"
  local repo_dir
  repo_dir=$(dirname "$git_dir")

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return
  fi

  # Corrected: Pass all array elements as separate arguments
  if has_author_commits "$repo_dir" "${default_authors[@]}"; then
    authored_directories+=("$repo_dir")
  fi
}

# --- Execute ---

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
