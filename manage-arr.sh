#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Exit status of a pipeline is the status of the last command to exit with a non-zero status.
set -o pipefail

#================================================================================#
#     Arr-Stack Management Script by t3kkn0 (Simplified Version)         #
#================================================================================#
#  This script helps manage the Arr-Stack docker deployment.           #
#  - Clones the repository if it doesn't exist.                      #
#  - Provides a menu for installation, uninstallation, updates, and backups.    #
#  - Uses a hardcoded list of paths for setup clarity and simplicity.      #
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

# Base path for NAS data. Used for the folder preparation function.
readonly NAS_BASE_PATH="/mnt/NAS-DATA"

# --- END CONFIGURATION ---


# --- SCRIPT COLORS (disables itself if not in an interactive terminal) ---
if [ -t 1 ]; then
    readonly C_RESET='\033[0m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_CYAN='\033[0;96m'
else
    readonly C_RESET=''
    readonly C_RED=''
    readonly C_GREEN=''
    readonly C_YELLOW=''
    readonly C_BLUE=''
    readonly C_CYAN=''
fi


# --- FUNCTIONS ---

# Function to check for required dependencies
check_dependencies() {
    local missing_deps=()
    # Check for only the essential programs
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
    echo -e " ${C_GREEN}1. Install Stack${C_RESET} (Prepares NAS, Clones/Pulls, copies .env, and starts)"
    echo -e " ${C_RED}2. Uninstall Stack${C_RESET} (Stops and removes containers/volumes)"
    echo -e " ${C_BLUE}3. Reload Stack${C_RESET} (Pulls latest from Git & Docker, then restarts)"
    echo ""
    echo -e " ${C_GREEN}4. Backup Configuration${C_RESET} (Archives config folders and .env file)"
    echo -e " ${C_RED}5. Restore Configuration${C_RESET} (Restores from a backup archive)"
    echo ""
    echo -e " ${C_YELLOW}6. View Live Logs${C_RESET} (Follows logs from all containers)"
    echo -e " ${C_YELLOW}7. Prune Docker System${C_RESET} (Remove unused images/volumes/networks)"
    echo -e " ${C_RED}8. DESTROY Config Folders${C_RESET} (Deletes ALL app config folders from NAS)"
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

# Function: Prepare NAS folders using a hardcoded list
prepare_nas_folders() {
    echo -e "${C_BLUE}--- Preparing NAS Folders ---${C_RESET}"
    echo "This will create a predefined list of directories and set their permissions."
    echo "This script assumes you are running it with sufficient privileges (e.g., sudo)."
    read -p "Do you want to continue? [Y/n]: " confirm

    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo "Skipping NAS folder preparation."
        return
    fi

    # --- Create Directories (one by one for clarity) ---
    echo "Creating media, download, and application config directories..."
    sudo mkdir -p "${NAS_BASE_PATH}/Downloads/complete"
    sudo mkdir -p "${NAS_BASE_PATH}/Downloads/incomplete"
    sudo mkdir -p "${NAS_BASE_PATH}/tvshows"
    sudo mkdir -p "${NAS_BASE_PATH}/movies"
    sudo mkdir -p "${NAS_BASE_PATH}/anime"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Radarr/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Radarr/backup"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Sonarr/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Sonarr/backup"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Sonarr-Anime/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Bazarr/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Prowlarr/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Prowlarr/backup"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/nzbget/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/qbittorrent/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/rdt-client/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Homarr/configs"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Homarr/icons"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Homarr/data"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Jellyseerr/config"
    sudo mkdir -p "${CONFIG_BASE_ON_HOST}/Emby/config"

    # --- Set Permissions ---
    # Get PUID/PGID from the .env file to set correct ownership
    local puid=1000 # Default PUID
    local pgid=1000 # Default PGID
    if [ -f "$STACK_DIR/.env" ]; then
        PUID_VAL=$(grep -E '^\s*PUID=' "$STACK_DIR/.env" | cut -d'=' -f2)
        PGID_VAL=$(grep -E '^\s*PGID=' "$STACK_DIR/.env" | cut -d'=' -f2)
        if [ -n "$PUID_VAL" ]; then puid=$PUID_VAL; fi
        if [ -n "$PGID_VAL" ]; then pgid=$PGID_VAL; fi
    fi

    echo "Setting ownership for all stack-related data to User ${puid} / Group ${pgid}..."
    # Set ownership on each directory individually for maximum clarity.
    sudo chown -R "${puid}:${pgid}" "${NAS_BASE_PATH}/Downloads"
    sudo chown -R "${puid}:${pgid}" "${NAS_BASE_PATH}/tvshows"
    sudo chown -R "${puid}:${pgid}" "${NAS_BASE_PATH}/movies"
    sudo chown -R "${puid}:${pgid}" "${NAS_BASE_PATH}/anime"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Radarr/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Radarr/backup"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Sonarr/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Sonarr/backup"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Sonarr-Anime/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Bazarr/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Prowlarr/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Prowlarr/backup"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/nzbget/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/qbittorrent/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/rdt-client/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Homarr/configs"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Homarr/icons"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Homarr/data"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Jellyseerr/config"
    sudo chown -R "${puid}:${pgid}" "${CONFIG_BASE_ON_HOST}/Emby/config"

    echo -e "${C_GREEN}--- NAS Folder Preparation Complete ---${C_RESET}"
}


# Function 1: Install the Docker stack
install_stack() {
    echo -e "${C_BLUE}--- Starting Stack Installation ---${C_RESET}"

    # --- Clone or Pull Repo ---
    if [ ! -d "$STACK_DIR" ]; then
        echo "Directory $STACK_DIR not found. Cloning repository..."
        git clone "$REPO_URL" "$STACK_DIR"
    else
        echo "Stack directory already exists. Pulling latest changes from repository..."
        (cd "$STACK_DIR" && git pull)
    fi

    # --- Handle .env file ---
    # This must be done BEFORE preparing folders so we can get PUID/PGID
    if [ -f "$ENV_SOURCE_PATH" ]; then
        echo "Master .env file found. Copying it to the stack directory..."
        cp "$ENV_SOURCE_PATH" "$STACK_DIR/.env"
    else
        echo -e "${C_YELLOW}Warning: Master .env file not found at '$ENV_SOURCE_PATH'.${C_RESET}"
        local repo_env_path="$STACK_DIR/.env"
        if [ -f "$repo_env_path.template" ] && [ ! -f "$repo_env_path" ]; then
             echo "Found .env.template in repository, copying it to .env"
             cp "$repo_env_path.template" "$repo_env_path"
        fi

        if [ -f "$repo_env_path" ]; then
            echo "Found .env file in the repository. Using it as a template."
            echo "Saving a copy to your master location ('$ENV_SOURCE_PATH') for future use..."
            mkdir -p "$(dirname "$ENV_SOURCE_PATH")"
            cp "$repo_env_path" "$ENV_SOURCE_PATH"

            echo -e "\n${C_RED}================== ACTION REQUIRED ==================${C_RESET}"
            echo -e "${C_YELLOW}A template .env file was copied. You MUST edit the file at:${C_RESET}"
            echo -e "${C_CYAN}$ENV_SOURCE_PATH${C_RESET}"
            echo -e "${C_YELLOW}with your correct paths and settings (TZ, PUID, PGID) before the stack will work properly!${C_RESET}"
            echo -e "${C_RED}=====================================================${C_RESET}\n"
            read -p "Press Enter to continue, or CTRL+C to exit and edit the file now."
        else
            echo -e "${C_RED}Error: No master .env file found and no .env or .env.template could be located in the repository.${C_RESET}"
            echo -e "${C_YELLOW}Please create a .env file at '$ENV_SOURCE_PATH' and run the script again.${C_RESET}"
            return 1
        fi
    fi

    # --- Prepare NAS folders (now uses hardcoded logic) ---
    prepare_nas_folders

    # --- Start Containers ---
    echo "Starting Docker containers..."
    (cd "$STACK_DIR" && docker compose up -d)
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

    echo -e "${C_YELLOW}This will NOT touch your media libraries (movies/TV shows).${C_RESET}"
    read -p "Do you also want to remove all associated volumes (DELETES APP CONFIGS)? [y/N]: " confirm_volumes

    if [[ "$confirm_volumes" == "y" || "$confirm_volumes" == "Y" ]]; then
        echo -e "${C_RED}WARNING: Stopping containers AND removing volumes... This is permanent!${C_RESET}"
        docker compose down -v
    else
        echo "Stopping containers but leaving volumes intact..."
        docker compose down
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

    if [ ! -f "$ENV_SOURCE_PATH" ]; then
        echo -e "${C_RED}Error: Master .env file not found at '$ENV_SOURCE_PATH'. Cannot reload without it.${C_RESET}"
        return 1
    fi

    cd "$STACK_DIR" || return

    echo "Pulling latest changes from Git..."
    git pull

    echo "Pulling latest Docker images..."
    docker compose pull

    echo "Copying master .env file from $ENV_SOURCE_PATH to ensure stack is in sync..."
    cp "$ENV_SOURCE_PATH" "$STACK_DIR/.env"

    echo "Recreating containers with new images/configuration..."
    docker compose up -d --force-recreate --remove-orphans

    echo -e "${C_GREEN}--- Stack Reload Complete ---${C_RESET}"
}

# Function 4: Backup configuration files
backup_configs() {
    echo -e "${C_BLUE}--- Starting Configuration Backup ---${C_RESET}"

    if [ ! -d "$CONFIG_BASE_ON_HOST" ]; then
        echo -e "${C_RED}Error: Source configuration path not found at '$CONFIG_BASE_ON_HOST'. Please check the script configuration.${C_RESET}"
        return 1
    fi
    if [ ! -f "$ENV_SOURCE_PATH" ]; then
        echo -e "${C_RED}Error: Master .env file not found at '$ENV_SOURCE_PATH'. Cannot create a complete backup.${C_RESET}"
        return 1
    fi

    mkdir -p "$BACKUP_DEST_DIR"
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H%M%S")
    local backup_file="$BACKUP_DEST_DIR/arr-stack-backup-${timestamp}.tar.gz"

    echo "Creating backup archive..."
    echo "Source (configs): $CONFIG_BASE_ON_HOST"
    echo "Source (.env): $ENV_SOURCE_PATH"
    echo "Destination: $backup_file"

    # The -P flag tells tar to not strip the leading '/' from file names.
    if tar -Pzcf "$backup_file" "$CONFIG_BASE_ON_HOST" "$ENV_SOURCE_PATH"; then
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
    (cd "$STACK_DIR" && docker compose down)

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
        mkdir -p "$CONFIG_BASE_ON_HOST"
        rsync -a --delete "$temp_dir$CONFIG_BASE_ON_HOST/" "$CONFIG_BASE_ON_HOST/"
    fi

    if [ -f "$temp_dir$ENV_SOURCE_PATH" ]; then
        echo "Restoring master .env file from $temp_dir$ENV_SOURCE_PATH"
        mkdir -p "$(dirname "$ENV_SOURCE_PATH")"
        cp "$temp_dir$ENV_SOURCE_PATH" "$ENV_SOURCE_PATH"
    fi

    # Clean up the temporary directory and the trap
    rm -rf -- "$temp_dir"
    trap - EXIT

    echo -e "${C_GREEN}--- Restore Complete ---${C_RESET}"
    read -p "Do you want to start the stack now? [y/N]: " start_now
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        install_stack
    else
        echo "You can start your stack again later using Option 1 or 3."
    fi
}

# Function 6: View live logs
view_logs() {
    if [ ! -d "$STACK_DIR" ]; then
        echo -e "${C_RED}Error: Stack directory not found. Is the stack installed?${C_RESET}"
        return
    fi
    echo "Showing live logs for all services. Press CTRL+C to stop."
    (cd "$STACK_DIR" && docker compose logs -f)
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

# Function 8: Destroy configuration folders on the NAS
destroy_config_folders() {
    echo -e "${C_RED}--- Starting Configuration Folder DESTRUCTION ---${C_RESET}"
    echo -e "${C_RED}!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!${C_RESET}"
    echo -e "${C_YELLOW}This is a highly destructive and IRREVERSIBLE action.${C_RESET}"
    echo "This will permanently delete the MAIN application configuration directory"
    echo "from your host system. It is intended for a complete application reset."
    echo ""
    echo -e "${C_YELLOW}This will NOT touch:${C_RESET}"
    echo " - Your media libraries (movies, tvshows, anime)"
    echo " - Your downloads folder"
    echo " - The git repository in ${STACK_DIR}"
    echo ""
    echo "The following directory and ALL ITS CONTENTS will be DELETED:"
    echo -e " - ${C_CYAN}${CONFIG_BASE_ON_HOST}${C_RESET}"
    echo ""
    read -p "To confirm, type the word 'DESTROY' and press Enter: " confirm_destroy

    if [[ "$confirm_destroy" != "DESTROY" ]]; then
        echo "Confirmation failed. Aborting."
        return
    fi

    if [ ! -d "$CONFIG_BASE_ON_HOST" ]; then
        echo "Directory ${CONFIG_BASE_ON_HOST} not found. Nothing to delete."
        return
    fi

    echo "Confirmation received. Proceeding with deletion..."
    if sudo rm -rf "${CONFIG_BASE_ON_HOST}"; then
        echo -e "${C_GREEN}--- Configuration Folder Destruction Complete ---${C_RESET}"
    else
        echo -e "${C_RED}--- Destruction Failed ---${C_RESET}"
    fi
}


# --- MAIN SCRIPT LOGIC ---

# Check dependencies and config first
check_dependencies
check_config

while true; do
    show_menu
    read -p "Enter your choice [0-8]: " choice

    case $choice in
        1) install_stack ;;
        2) uninstall_stack ;;
        3) reload_stack ;;
        4) backup_configs ;;
        5) restore_configs ;;
        6) view_logs ;;
        7) prune_docker ;;
        8) destroy_config_folders ;;
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
