#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Exit status of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

#================================================================================#
#         Arr-Stack Management Script by t3kkn0 (Improved Version)               #
#================================================================================#
#  This script helps manage the Arr-Stack docker deployment.                     #
#  - Clones the repository if it doesn't exist.                                  #
#  - Provides a menu for installation, uninstallation, updates, and backups.     #
#  - Includes safety checks and improved error handling.                         #
#================================================================================#

# --- BEGIN CONFIGURATION ---
# --- (PATHS CONFIGURED BASED ON YOUR INPUT) ---

# The URL of the docker-compose git repository.
readonly REPO_URL="https://github.com/t3kkn0/Arr-Stack.git"

# The local directory where you want to clone the Arr-Stack repository.
readonly STACK_DIR="/opt/arr-stack"

# The FULL path to your master .env file. This file will be COPIED and will
# OVERWRITE the .env file in the STACK_DIR during install and reload operations.
readonly ENV_SOURCE_PATH="/mnt/NAS-DATA/Arr-stackBACKUPS/.env"

# The directory on the HOST machine where you want to store backups.
readonly BACKUP_DEST_DIR="/mnt/NAS-DATA/Arr-stackBACKUPS"

# This is the base path ON THE HOST where your container CONFIG folders are stored.
# IMPORTANT: This path should ONLY contain application configuration data.
# Your media libraries (movies, TV shows, etc.) should be in a COMPLETELY
# SEPARATE directory to ensure they are never touched by this script's operations.
readonly CONFIG_BASE_ON_HOST="/mnt/NAS-DATA/DOCKER/Arr-Stack"

# --- END CONFIGURATION ---


# --- SCRIPT COLORS ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;96m'


# --- FUNCTIONS ---

# Function to check for required dependencies
check_dependencies() {
    local missing_deps=()
    for dep in git docker; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${C_RED}Error: Missing required dependencies: ${missing_deps[*]}.${C_RESET}"
        echo -e "${C_YELLOW}Please install them and try again.${C_RESET}"
        exit 1
    fi
    # Also check for Docker Compose v2 compatibility
    if ! docker compose version &> /dev/null; then
        echo -e "${C_RED}Error: This script requires Docker Compose V2 (the 'docker compose' command).${C_RESET}"
        echo -e "${C_YELLOW}Please ensure your Docker installation is up-to-date.${C_RESET}"
        exit 1
    fi
}


# Function to display the main menu
show_menu() {
    echo -e "${C_CYAN}=============================================${C_RESET}"
    echo -e "${C_CYAN}         Arr-Stack Management Menu           ${C_RESET}"
    echo -e "${C_CYAN}=============================================${C_RESET}"
    echo -e " Stack is located at: ${C_YELLOW}${STACK_DIR}${C_RESET}"
    echo ""
    echo -e " ${C_GREEN}1. Install Stack${C_RESET} (Clones repo, copies .env, and starts containers)"
    echo -e " ${C_RED}2. Uninstall Stack${C_RESET} (Stops and removes containers)"
    echo -e " ${C_BLUE}3. Reload Stack${C_RESET} (Pulls latest from Git & Docker, then restarts)"
    echo ""
    echo -e " ${C_GREEN}4. Backup Configuration${C_RESET} (Archives all config folders and .env file)"
    echo -e " ${C_RED}5. Restore Configuration${C_RESET} (Restores from a backup archive)"
    echo ""
    echo -e " ${C_YELLOW}6. View Live Logs${C_RESET} (Follows logs from all containers)"
    echo -e " ${C_YELLOW}7. Prune Docker System${C_RESET} (Remove unused images/volumes/networks)"
    echo ""
    echo -e " ${C_CYAN}0. Exit${C_RESET}"
    echo ""
}

# Function to check if critical paths are set
check_config() {
    if [ -z "$STACK_DIR" ] || [ -z "$ENV_SOURCE_PATH" ] || [ -z "$BACKUP_DEST_DIR" ] || [ -z "$CONFIG_BASE_ON_HOST" ]; then
        echo -e "${C_RED}Error: One or more critical path variables are not set in the script's configuration section. Please edit the script and try again.${C_RESET}"
        exit 1
    fi
}

# Function to copy the master .env file
copy_env_file() {
    if [ -f "$ENV_SOURCE_PATH" ]; then
        echo "Copying master .env file from $ENV_SOURCE_PATH and overwriting..."
        cp "$ENV_SOURCE_PATH" "$STACK_DIR/.env"
    else
        echo -e "${C_RED}Error: Master .env file not found at $ENV_SOURCE_PATH. Aborting.${C_RESET}"
        return 1
    fi
}

# Function 1: Install the Docker stack
install_stack() {
    echo -e "${C_BLUE}--- Starting Stack Installation ---${C_RESET}"

    # Clone the repo if the directory doesn't exist
    if [ ! -d "$STACK_DIR" ]; then
        echo "Directory $STACK_DIR not found. Cloning repository..."
        git clone "$REPO_URL" "$STACK_DIR"
    else
        echo "Stack directory already exists. Skipping clone."
    fi

    # Copy the .env file
    copy_env_file || return 1

    # Navigate to the stack directory and start the containers
    cd "$STACK_DIR" || return
    echo "Starting Docker containers..."
    docker compose up -d
    echo -e "${C_GREEN}--- Stack Installation Complete ---${C_RESET}"
}

# Function 2: Uninstall the Docker stack
uninstall_stack() {
    echo -e "${C_RED}--- Starting Stack Uninstallation ---${C_RESET}"
    if [ ! -d "$STACK_DIR" ]; then
        echo -e "${C_YELLOW}Stack directory not found. Nothing to do.${C_RESET}"
        return
    fi

    cd "$STACK_DIR" || return

    echo "This will stop and remove all containers defined in the compose file."
    read -p "Are you sure you want to continue? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting."
        return
    fi

    echo "Stopping containers..."
    docker compose down

    echo -e "${C_YELLOW}This will permanently delete the application config data stored in Docker volumes.${C_RESET}"
    echo -e "${C_YELLOW}This will NOT touch your media libraries (movies/TV shows) if they are in a separate path.${C_RESET}"
    read -p "Do you also want to remove all associated volumes (DELETES APP CONFIGS)? [y/N]: " confirm_volumes
    if [[ "$confirm_volumes" == "y" || "$confirm_volumes" == "Y" ]]; then
        echo -e "${C_RED}WARNING: Removing volumes... This is permanent!${C_RESET}"
        docker compose down -v
    fi

    echo -e "${C_GREEN}--- Stack Uninstallation Complete ---${C_RESET}"
}

# Function 3: Pull latest updates and reload the stack
reload_stack() {
    echo -e "${C_BLUE}--- Reloading Stack ---${C_RESET}"
    if [ ! -d "$STACK_DIR" ]; then
        echo -e "${C_RED}Error: Stack directory $STACK_DIR not found. Please install the stack first (Option 1).${C_RESET}"
        return 1
    fi

    cd "$STACK_DIR" || return

    echo "Pulling latest changes from Git..."
    git pull

    echo "Pulling latest Docker images..."
    docker compose pull

    # Copy the .env file again to ensure it's up-to-date
    copy_env_file || return 1

    echo "Recreating containers with new images/configuration..."
    docker compose up -d --force-recreate

    echo -e "${C_GREEN}--- Stack Reload Complete ---${C_RESET}"
}

# Function 4: Backup configuration files
backup_configs() {
    echo -e "${C_BLUE}--- Starting Configuration Backup ---${C_RESET}"

    # Check if source config directory exists
    if [ ! -d "$CONFIG_BASE_ON_HOST" ]; then
        echo -e "${C_RED}Error: Source configuration path not found at '$CONFIG_BASE_ON_HOST'. Please check the CONFIG_BASE_ON_HOST variable in the script.${C_RESET}"
        return 1
    fi

    # Create backup destination if it doesn't exist
    mkdir -p "$BACKUP_DEST_DIR"

    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H%M%S")
    local backup_file="$BACKUP_DEST_DIR/arr-stack-backup-${timestamp}.tar.gz"

    echo "Creating backup archive..."
    echo "Source (configs): $CONFIG_BASE_ON_HOST"
    echo "Source (.env): $ENV_SOURCE_PATH"
    echo "Destination: $backup_file"

    # Create the archive. The -P flag tells tar to not strip the leading '/' from file names.
    tar -Pzcf "$backup_file" "$CONFIG_BASE_ON_HOST" "$ENV_SOURCE_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}--- Backup Complete ---${C_RESET}"
        echo "Backup saved to $backup_file"
    else
        echo -e "${C_RED}--- Backup Failed ---${C_RESET}"
    fi
}

# Function 5: Restore configuration from a backup
restore_configs() {
    echo -e "${C_RED}--- Starting Configuration Restore ---${C_RESET}"

    # Use a process substitution with `ls -t` to sort by time (newest first)
    mapfile -t sorted_backups < <(ls -t "$BACKUP_DEST_DIR"/*.tar.gz 2>/dev/null)

    if [ ${#sorted_backups[@]} -eq 0 ]; then
        echo -e "${C_YELLOW}No backup files found in $BACKUP_DEST_DIR${C_RESET}"
        return
    fi

    echo -e "${C_YELLOW}Available backups (newest first):${C_RESET}"
    select backup_file in "${sorted_backups[@]}"; do
        if [ -n "$backup_file" ]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    echo ""
    echo -e "${C_RED}!!! WARNING !!!${C_RESET}"
    echo "This will STOP your current stack and OVERWRITE all current configuration"
    echo "with the contents of:"
    echo -e "${C_YELLOW}$backup_file${C_RESET}"
    read -p "This is a destructive action. Are you absolutely sure? [y/N]: " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting."
        return
    fi

    echo "Stopping containers before restore..."
    cd "$STACK_DIR" || return
    docker compose down

    # Create a secure temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    # Ensure cleanup on script exit or error
    trap 'rm -rf -- "$temp_dir"' EXIT

    echo "Extracting backup to a temporary, safe location..."
    tar -Pxzf "$backup_file" -C "$temp_dir"

    echo "Restoring files from temp location..."
    # Use rsync for safety and efficiency. The trailing slashes are important!
    if [ -d "$temp_dir$CONFIG_BASE_ON_HOST/" ]; then
        echo "Restoring main config from $temp_dir$CONFIG_BASE_ON_HOST"
        # Ensure the parent directory exists before restoring
        mkdir -p "$CONFIG_BASE_ON_HOST"
        rsync -a --delete "$temp_dir$CONFIG_BASE_ON_HOST/" "$CONFIG_BASE_ON_HOST/"
    fi

    if [ -f "$temp_dir$ENV_SOURCE_PATH" ]; then
        echo "Restoring master .env file from $temp_dir$ENV_SOURCE_PATH"
        # Ensure the parent directory exists before restoring
        mkdir -p "$(dirname "$ENV_SOURCE_PATH")"
        cp "$temp_dir$ENV_SOURCE_PATH" "$ENV_SOURCE_PATH"
    fi

    # Clean up the temporary directory
    rm -rf -- "$temp_dir"
    trap - EXIT # Clear the trap

    echo -e "${C_GREEN}--- Restore Complete ---${C_RESET}"
    read -p "Do you want to start the stack now? [y/N]: " start_now
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        install_stack
    else
        echo "You can start your stack again later using Option 1."
    fi
}

# Function 6: View live logs
view_logs() {
    if [ ! -d "$STACK_DIR" ]; then
        echo -e "${C_RED}Error: Stack directory not found. Is the stack installed?${C_RESET}"
        return
    fi
    cd "$STACK_DIR" || return
    echo "Showing live logs for all services. Press CTRL+C to stop."
    docker compose logs -f
}

# Function 7: Prune Docker system
prune_docker() {
    echo -e "${C_RED}!!! WARNING !!!${C_RESET}"
    echo "This will remove all stopped containers, unused networks, dangling images,"
    echo "and the build cache. This can free up a lot of space but is irreversible."
    read -p "Are you sure you want to prune the Docker system? [y/N]: " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting."
        return
    fi

    docker system prune -a -f
    echo -e "${C_GREEN}Docker system prune complete.${C_RESET}"
}


# --- MAIN SCRIPT LOGIC ---

# Check dependencies and config first
check_dependencies
check_config

while true; do
    show_menu
    read -p "Enter your choice [0-7]: " choice

    case $choice in
        1) install_stack ;;
        2) uninstall_stack ;;
        3) reload_stack ;;
        4) backup_configs ;;
        5) restore_configs ;;
        6) view_logs ;;
        7) prune_docker ;;
        0) echo "Exiting. Goodbye!"; break ;;
        *) echo -e "${C_RED}Invalid option. Please try again.${C_RESET}" ;;
    esac

    if [ "$choice" != "0" ]; then
        read -n 1 -s -r -p "Press any key to return to the menu..."
        echo ""
    fi
    # Use 'tput clear' or 'clear' for better terminal clearing
    tput clear || clear
done
