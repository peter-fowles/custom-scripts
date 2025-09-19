#!/bin/bash

# ==============================================================================
# git_authors - A script to list all authors and optionally the directories they have contributed to.
#
# Features:
#   - Lists all unique authors across all Git repositories under a specified root.
#   - Optionally lists the directories each author has contributed to via the -d flag.
#   - Optionally formats authors with quotation marks for easy copying via the -q flag.
#   - Automatically uses the ignored directories defined in `default_values.conf` or `default_values.conf.example`.
#   - Excludes directories from the search based on command-line arguments.
#   - Robust error handling for invalid arguments.
#   - Color-coded output for improved readability.
#
# Usage:
#   git_authors [<directory>] [-i <dir1,dir2,...>] [-d] [-q] [-h]
#
# Examples:
#   # List all authors in the current working directory
#   git_authors
#
#   # List all authors and their directories in a specific directory
#   git_authors ~/projects -d
#
#   # List all authors formatted for copying to the config file
#   git_authors -q
#
#   # List all authors in a specific directory, ignoring 'temp'
#   git_authors ~/projects -i "temp"
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
declare -A authors_to_repos

# --- Argument Parsing ---
# Variables are populated by parse_args
root_directory="$(pwd)"
user_ignored_dirs=""
show_directories=false
format_quoted=false

usage() {
  echo -e "${BOLD}Usage:${NC} $0 [<directory>] [-i <dir1,dir2,...>] [-d] [-q] [-h]"
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  <directory>               Optional. The root directory to start searching for Git repos."
  echo "                            Defaults to the current working directory."
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  -i <dir1,dir2,...>        Optional. Append additional directories to the ignore list."
  echo "                            Provide a comma-separated string with no spaces."
  echo "  -d                        List the directories each unique author has contributed to."
  echo "  -q                        Formats the author names with quotes for easy copying."
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

  mapfile -t repo_authors < <(git -C "$repo_dir" log --format="%an <%ae>" --all | sort -u)

  for author in "${repo_authors[@]}"; do
    authors_to_repos["$author"]+="|$repo_dir"
  done
}

# --- Execute ---

# Load configuration
load_config

# Prepare arguments for parsing
# Short options: i:dqh
# Long options: ignore-dirs:,directories,quoted,help
parse_args "$0" "i:dqh" "ignore-dirs:,directories,quoted,help" "$@"

# Perform post-parsing validation and set final ignored directories
local all_ignored_dirs=("${default_ignored_dirs[@]}")
if [[ -n "$user_ignored_dirs" ]]; then
  IFS=',' read -ra user_dirs_array <<< "$user_ignored_dirs"
  all_ignored_dirs=("${user_dirs_array[@]}")
fi
declare -A unique_dirs
for dir in "${all_ignored_dirs[@]}"; do
  unique_dirs["$dir"]=1
done
final_ignored_dirs=("${!unique_dirs[@]}")

# Execute script logic
if [[ ! -d "$root_directory" ]]; then
  echo -e "${RED}Error:${NC} The specified directory '${BOLD}$root_directory${NC}' does not exist." >&2
  exit 1
fi

echo -e "${BOLD}Finding all authors in '${CYAN}$root_directory${NC}'...${NC}"

if [[ ${#final_ignored_dirs[@]} -gt 0 ]]; then
  echo -e "Ignoring directories: ${YELLOW}${final_ignored_dirs[*]}${NC}"
fi
echo ""

process_repos_common "$root_directory" "${final_ignored_dirs[@]}"

if [[ ${#authors_to_repos[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No authors found in non-ignored directories.${NC}"
else
  echo -e "${BOLD}--- All unique authors ${show_directories:+"and their contributed directories"}:${NC}"
  sorted_authors=()
  mapfile -t sorted_authors < <(for key in "${!authors_to_repos[@]}"; do echo "$key"; done | sort)

  for author in "${sorted_authors[@]}"; do
    if [[ "$format_quoted" = true ]]; then
      printf "\"%s\"\n" "$author"
    elif [[ "$show_directories" = true ]]; then
      printf "${GREEN}%s:${NC}\n" "$author"
      repos=${authors_to_repos["$author"]}
      repos=${repos#|}
      repos=${repos//|/$'\n'$(printf "%${#author}s" "")$'  '}
      printf "  %s\n" "$repos"
      echo ""
    else
      printf "${GREEN}%s${NC}\n" "$author"
    fi
  done
  
  if [[ "$show_directories" = true && "$format_quoted" = false ]]; then
      echo ""
  fi
fi

echo -e "\n${BOLD}Finished git_authors.${NC}"
