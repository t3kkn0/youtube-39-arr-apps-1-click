#!/usr/bin/env bash
#
################################################################################
#
#  Arr-Stack Management Script
#
#  Description:
#    Manages the Arr-Stack docker deployment. It handles installation,
#    uninstallation, updates, backups, and other maintenance tasks.
#
#  Usage:
#    sudo ./arr-stack-manager.sh
#
#  Dependencies:
#    - git
#    - docker (with compose v2 plugin)
#    - rsync
#
################################################################################

# --- Strict Mode & Boilerplate ---
# Exit on error, treat unset variables as errors, and fail pipelines on error.
set -euo pipefail

# --- Configuration ---
# The URL of the docker-compose git repository.
readonly REPO_URL="https://github.com/t3kkn0/Arr-Stack.git"
# The local directory where the Arr-Stack repository will be cloned.
readonly STACK_DIR="/opt/arr-stack"
# The FULL path to your master .env file.
readonly ENV_SOURCE_PATH="/mnt/NAS-DATA/Arr-stackBACKUPS/.env"
# The directory on the HOST machine for backups.
readonly BACKUP_DEST_DIR="/mnt/NAS-DATA/Arr-stackBACKUPS"
# The base path ON THE VM for container CONFIG folders.
readonly CONFIG_BASE_ON_HOST="/var/lib/docker/volumes/arr-stack_config"
# An array of all NAS mount points the script depends on.
# These are only for backups and media now.
readonly REQUIRED_MOUNTS=(
  "/mnt/NAS-DATA"
  "/mnt/NAS-MEDIA"
  "/mnt/NAS-DOCKER"
)
# Lock file to prevent concurrent script execution.
readonly LOCK_FILE="/var/lock/arr_stack_manager.lock"

# --- Logging & Colors ---
# Script logging is now handled by functions for consistency.
# Colors are enabled if the script is run in an interactive terminal.
if [[ -t 1 ]]; then
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

# --- Global Variables ---
# A temporary directory for this script's execution.
# It will be created by mktemp and cleaned up by the exit trap.
TMP_DIR=""

#######################################
# Ensures the script exits cleanly, removing temporary resources.
# This trap is triggered on EXIT, which includes normal exit,
# exit due to 'set -e', and signals like INT/TERM.
# Globals:
#   TMP_DIR
#   LOCK_FILE
# Arguments:
#   None
#######################################
function cleanup() {
  # The '|| true' is to prevent the trap from exiting with an error if the
  # variables are not set (e.g., if the script fails before they are defined).
  rm -f "${LOCK_FILE-}" || true
  if [[ -n "${TMP_DIR-}" ]]; then
    rm -rf "${TMP_DIR}" || true
  fi
}
trap cleanup EXIT

# --- Utility & Helper Functions ---

#######################################
# Generic logging function.
# Arguments:
#   $1 - Log level (e.g., INFO, WARN, ERROR)
#   $2 - Color for the log level
#   $3 - Message to log
#######################################
function log() {
  local level="$1"
  local color="$2"
  local message="$3"
  echo -e "${color}[${level}]${C_RESET} ${message}"
}

function log_info() { log "INFO" "${C_GREEN}" "$1"; }
function log_warn() { log "WARN" "${C_YELLOW}" "$1"; }
function log_error() { log "ERROR" "${C_RED}" "$1" >&2; }
function log_fatal() { log "FATAL" "${C_RED}" "$1" >&2; exit 1; }
function log_prompt() { echo -e "${C_CYAN}==>${C_RESET} $1"; }

#######################################
# Checks if a given mount point is a healthy, responsive NFS mount.
# This function has a built-in timeout to prevent script hangs.
# Arguments:
#   $1 - The path to the mount point to check.
# Returns:
#   0 if the mount is healthy.
#   1 if the mount is stale, unresponsive, or not an NFS mount.
#######################################
function is_nfs_mount_healthy() {
  local mount_point="$1"
  if ! mountpoint -q "$mount_point"; then
    log_error "Path $mount_point is not a valid mount point."
    return 1
  fi
  # 'stat -f' is a low-impact way to test the connection. A 5-second timeout is generous.
  if ! timeout 5s stat -f "$mount_point" >/dev/null 2>&1; then
    log_error "NFS mount $mount_point is stale or unresponsive."
    return 1
  fi
  return 0
}

#######################################
# Checks all critical NFS mounts required by the script.
# Arguments:
#   None
# Returns:
#   Exits script if any mount is unhealthy.
#######################################
function check_all_mounts() {
  log_info "Verifying health of all required NAS mounts..."
  for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! is_nfs_mount_healthy "$mount"; then
      log_fatal "A required NAS mount is unhealthy. Please check your NFS connection and the Synology NAS, then try again."
    fi
  done
  log_info "All NAS mounts are healthy."
}

#######################################
# Checks for required command-line dependencies.
# Arguments:
#   None
# Returns:
#   Exits script if a dependency is missing.
#######################################
function check_dependencies() {
  log_info "Checking for required dependencies..."
  local missing_deps=()
  local required_cmds=("git" "docker" "rsync")
  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    log_fatal "Missing required dependencies: ${missing_deps[*]}. Please install them and try again."
  fi

  if ! docker compose version &>/dev/null; then
    log_fatal "This script requires Docker Compose V2 (the 'docker compose' command). Please ensure your Docker installation is up-to-date."
  fi
  log_info "All dependencies are satisfied."
}

# --- Core Application Functions ---

function show_menu() {
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
  echo -e " ${C_RED}8. DESTROY Config Folders${C_RESET} (Deletes ALL app config folders from VM)"
  echo ""
  echo -e " ${C_CYAN}0. Exit${C_RESET}"
  echo ""
}

#######################################
# Prepares NAS folders for Media/Downloads and sets permissions.
# This function requires root privileges to run.
# Globals:
#   STACK_DIR
# Arguments:
#   None
#######################################
function prepare_nas_folders() {
    log_info "--- Preparing NAS Media/Download Folders ---"
    log_prompt "This will create media and download directories on the NAS and set their permissions."
    read -p "Do you want to continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_warn "Skipping NAS folder preparation."
        return
    fi

    local -a dirs_to_create=(
    # Media and Download Folders
    "/mnt/NAS-DATA/Downloads/complete"
    "/mnt/NAS-DATA/Downloads/incomplete"
    "/mnt/NAS-MEDIA/tvshows"
    "/mnt/NAS-MEDIA/movies"
    "/mnt/NAS-MEDIA/anime"
    # Application Backup Folders on the NAS
    "/mnt/NAS-DOCKER/Arr-Stack/Prowlarr/backup"
    "/mnt/NAS-DOCKER/Arr-Stack/Radarr/backup"
    "/mnt/NAS-DOCKER/Arr-Stack/Sonarr/backup"
    "/mnt/NAS-DOCKER/Arr-Stack/Sonarr-Anime/backup"
    )

    log_info "Creating required directories on NAS mounts..."
    for dir in "${dirs_to_create[@]}"; do
        mkdir -p "$dir"
        log_info "  Ensured directory exists: $dir"
    done

    local puid="1026"
    local pgid="100"
    if [[ -f "${STACK_DIR}/.env" ]]; then
        puid=$(grep -E '^\s*PUID=' "${STACK_DIR}/.env" | cut -d'=' -f2 || echo "$puid")
        pgid=$(grep -E '^\s*PGID=' "${STACK_DIR}/.env" | cut -d'=' -f2 || echo "$pgid")
    else
        log_warn "No .env file found in ${STACK_DIR}. Using default PUID/PGID of 1026:100."
    fi

    log_info "Setting ownership for media and download data to User ${puid} / Group ${pgid}..."
    local downloads_parent="/mnt/NAS-DATA/Downloads"
    local media_parent="/mnt/NAS-MEDIA"

    if [ -d "${downloads_parent}" ]; then
        log_info "  Updating ownership for: ${downloads_parent}"
        chown -R "${puid}:${pgid}" "${downloads_parent}"
    fi
    if [ -d "${media_parent}" ]; then
        log_info "  Updating ownership for: ${media_parent}"
        chown -R "${puid}:${pgid}" "${media_parent}"
    fi
    log_info "--- NAS Folder Preparation Complete ---"
}

#######################################
# Installs the Docker stack or offers to restore.
# Globals:
#   STACK_DIR, REPO_URL, ENV_SOURCE_PATH
# Arguments:
#   None
#######################################
function install_stack() {
  # --- Offer to restore first ---
  read -p "Do you want to restore an existing configuration instead of a fresh installation? [y/N]: " confirm_restore
  if [[ "$confirm_restore" =~ ^[yY]$ ]]; then
      log_info "Switching to restore process..."
      restore_configs
      # The restore function handles the rest of the process, including starting the stack.
      # So we exit this function to avoid duplicate actions.
      log_info "Restore process initiated. Returning to main menu."
      return
  fi

  log_info "--- Starting Fresh Stack Installation ---"
  check_all_mounts

  # --- Clone or Pull Repo (Idempotent) ---
  if [[ ! -d "$STACK_DIR" ]]; then
    log_info "Directory $STACK_DIR not found. Cloning repository..."
    git clone "$REPO_URL" "$STACK_DIR"
  else
    log_info "Stack directory exists. Pulling latest changes..."
    (cd "$STACK_DIR" && git pull)
  fi

  # --- Handle .env file ---
  if [[ -f "$ENV_SOURCE_PATH" ]]; then
    log_info "Master .env file found. Copying to stack directory..."
    cp "$ENV_SOURCE_PATH" "$STACK_DIR/.env"
  else
    log_warn "Master .env file not found at $ENV_SOURCE_PATH."
    local repo_env_path="$STACK_DIR/.env"
    if [[ -f "$repo_env_path.template" && ! -f "$repo_env_path" ]]; then
      log_info "Found .env.template, copying to .env"
      cp "$repo_env_path.template" "$repo_env_path"
    fi

    if [[ -f "$repo_env_path" ]]; then
      log_info "Found .env in repository. Saving a copy to $ENV_SOURCE_PATH for future use."
      mkdir -p "$(dirname "$ENV_SOURCE_PATH")"
      cp "$repo_env_path" "$ENV_SOURCE_PATH"
      echo -e "\n${C_RED}================== ACTION REQUIRED ==================${C_RESET}"
      echo -e "${C_YELLOW}A template .env file was copied. You MUST edit the file at:${C_RESET}"
      echo -e "${C_CYAN}${ENV_SOURCE_PATH}${C_RESET}"
      echo -e "${C_YELLOW}with your correct settings (TZ, PUID, PGID) before the stack will work properly!${C_RESET}"
      echo -e "${C_RED}=====================================================${C_RESET}\n"
      read -p "Press Enter to continue, or CTRL+C to exit and edit the file now."
    else
      log_error "No master .env file found and no .env or .env.template in repository."
      log_error "Please create a .env file at $ENV_SOURCE_PATH and run again."
      return 1
    fi
  fi

  # --- Prepare NAS folders ---
  prepare_nas_folders

  # --- Start Containers ---
  log_info "Starting Docker containers..."
  (cd "$STACK_DIR" && docker compose up -d)
  log_info "--- Stack Installation Complete ---"
}


#######################################
# Uninstalls the Docker stack, offering backup first.
# Globals:
#   STACK_DIR
# Arguments:
#   None
#######################################
function uninstall_stack() {
  log_info "--- Starting Stack Uninstallation ---"
  if [[ ! -d "$STACK_DIR" ]]; then
    log_warn "Stack directory not found. Nothing to do."
    return
  fi

  # --- Offer to back up first ---
  read -p "Do you want to back up your current configuration before uninstalling? (Recommended) [y/N]: " confirm_backup
  if [[ "$confirm_backup" =~ ^[yY]$ ]]; then
    backup_configs
  fi

  log_prompt "This will stop and remove all containers defined in the compose file."
  read -p "Are you sure you want to continue with uninstallation? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    log_info "Aborting."
    return
  fi

  log_warn "This will NOT touch your media libraries (movies/TV shows) on the NAS."
  read -p "Do you also want to remove all associated volumes (DELETES LOCAL APP CONFIGS)? [y/N]: " confirm_volumes

  (
    cd "$STACK_DIR"
    if [[ "$confirm_volumes" =~ ^[yY]$ ]]; then
      log_warn "Stopping containers AND removing volumes... This is permanent!"
      docker compose down -v
    else
      log_info "Stopping containers but leaving volumes intact..."
      docker compose down
    fi
  )

  log_info "--- Stack Uninstallation Complete ---"
}


#######################################
# Pulls latest updates and reloads the stack.
# Globals:
#   STACK_DIR, ENV_SOURCE_PATH
# Arguments:
#   None
#######################################
function reload_stack() {
  log_info "--- Reloading Stack ---"
  check_all_mounts
  if [[ ! -d "$STACK_DIR" ]]; then
    log_error "Stack directory $STACK_DIR not found. Please install first (Option 1)."
    return 1
  fi
  if [[ ! -f "$ENV_SOURCE_PATH" ]]; then
    log_error "Master .env file not found at $ENV_SOURCE_PATH. Cannot reload."
    return 1
  fi

  (
    cd "$STACK_DIR"
    log_info "Pulling latest changes from Git..."
    git pull
    log_info "Pulling latest Docker images..."
    docker compose pull
    log_info "Copying master .env file to ensure stack is in sync..."
    cp "$ENV_SOURCE_PATH" "$STACK_DIR/.env"
    log_info "Recreating containers with new images/configuration..."
    docker compose up -d --force-recreate --remove-orphans
  )

  log_info "--- Stack Reload Complete ---"
}

#######################################
# Backs up local VM configuration files to the NAS.
# Globals:
#   CONFIG_BASE_ON_HOST, ENV_SOURCE_PATH, BACKUP_DEST_DIR
# Arguments:
#   None
#######################################
function backup_configs() {
    log_info "--- Starting Configuration Backup ---"
    check_all_mounts # Ensure NAS backup destination is available

    # Because we now use named volumes, we must inspect them to find their source on the host.
    local project_name
    project_name=$(basename "$STACK_DIR") # Assumes project name is the directory name
    local config_volumes_to_backup=()

    log_info "Identifying local config volumes to back up..."
    # Get a list of all volumes for this docker-compose project
    local all_volumes
    all_volumes=$(cd "$STACK_DIR" && docker compose config --volumes)

    # Filter for the ones we want (the ones ending in _config, _configs, _icons, _data)
    for volume in $all_volumes; do
        if [[ "$volume" == *"_config"* || "$volume" == *"_icons" || "$volume" == *"_data" ]]; then
            # Construct the full volume name as Docker sees it
            local full_volume_name="${project_name}_${volume}"
            # Find the actual path on the host system
            local source_path
            source_path=$(docker volume inspect -f '{{ .Mountpoint }}' "$full_volume_name")
            if [[ -d "$source_path" ]]; then
                log_info "  Found config volume '${volume}' at: ${source_path}"
                config_volumes_to_backup+=("$source_path")
            else
                log_warn "  Could not find host path for volume: ${volume}"
            fi
        fi
    done

    if [[ ${#config_volumes_to_backup[@]} -eq 0 ]]; then
        log_error "No local configuration volumes found to back up. This is unexpected."
        return 1
    fi
    if [[ ! -f "$ENV_SOURCE_PATH" ]]; then
        log_error "Master .env file not found at $ENV_SOURCE_PATH. Cannot create a complete backup."
        return 1
    fi

    mkdir -p "$BACKUP_DEST_DIR"
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H%M%S")
    local backup_file="$BACKUP_DEST_DIR/arr-stack-local-backup-${timestamp}.tar.gz"

    log_info "Creating backup archive..."
    log_info "  Source (.env):   $ENV_SOURCE_PATH"
    log_info "  Destination:     $backup_file"

    # Use tar to create the archive from the identified volume paths and the .env file
    if tar -Pzcf "$backup_file" "${config_volumes_to_backup[@]}" "$ENV_SOURCE_PATH"; then
        log_info "--- Backup Complete ---"
        log_info "Backup saved to $backup_file"
    else
        log_error "--- Backup Failed ---"
    fi
}


#######################################
# Restores configuration from a backup on the NAS to the local VM.
# Globals:
#   BACKUP_DEST_DIR, STACK_DIR, ENV_SOURCE_PATH, TMP_DIR
# Arguments:
#   None
#######################################
function restore_configs() {
    log_info "--- Starting Configuration Restore ---"
    check_all_mounts

    mapfile -t sorted_backups < <(find "$BACKUP_DEST_DIR" -maxdepth 1 -name '*.tar.gz' -print0 | xargs -0 ls -t 2>/dev/null)

    if [[ ${#sorted_backups[@]} -eq 0 ]]; then
        log_warn "No backup files found in $BACKUP_DEST_DIR"
        return
    fi

    log_prompt "Available backups (newest first):"
    local backup_file
    select backup_file in "${sorted_backups[@]}"; do
        if [[ -n "$backup_file" ]]; then
            break
        else
            log_warn "Invalid selection. Please try again."
        fi
    done

    echo ""
    log_warn "!!! WARNING !!!"
    log_warn "This will STOP your current stack and OVERWRITE all current LOCAL configuration volumes"
    log_warn "with the contents of: ${C_YELLOW}$backup_file${C_RESET}"
    read -p "This is a destructive action. Are you absolutely sure? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        log_info "Aborting."
        return
    fi

    log_info "Stopping containers before restore..."
    (cd "$STACK_DIR" && docker compose down)

    TMP_DIR=$(mktemp -d)
    log_info "Extracting backup to a temporary, safe location: $TMP_DIR"
    tar -Pxzf "$backup_file" -C "$TMP_DIR"

    log_info "Restoring files from temp location..."
    # The backup contains the full path, e.g., /var/lib/docker/volumes/arr-stack_prowlarr_config/_data
    # We need to restore it to the *current* volume mountpoints, which might have changed.
    # The safest way is to rsync the contents of the backed-up directories into the current ones.

    local project_name
    project_name=$(basename "$STACK_DIR")

    for backed_up_path in "${TMP_DIR}/var/lib/docker/volumes"/*; do
        if [[ -d "$backed_up_path" ]]; then
            local volume_name
            volume_name=$(basename "$backed_up_path")
            local current_volume_path
            current_volume_path=$(docker volume inspect -f '{{.Mountpoint}}' "$volume_name" 2>/dev/null || true)

            if [[ -n "$current_volume_path" && -d "$current_volume_path" ]]; then
                log_info "  Restoring to volume '${volume_name}'..."
                rsync -a --delete "${backed_up_path}/" "${current_volume_path}/"
            else
                log_warn "  Volume '${volume_name}' from backup does not exist in current stack. Skipping."
            fi
        fi
    done

    if [[ -f "${TMP_DIR}${ENV_SOURCE_PATH}" ]]; then
        log_info "Restoring master .env file from ${TMP_DIR}${ENV_SOURCE_PATH}"
        mkdir -p "$(dirname "$ENV_SOURCE_PATH")"
        cp "${TMP_DIR}${ENV_SOURCE_PATH}" "$ENV_SOURCE_PATH"
    fi

    log_info "--- Restore Complete ---"
    read -p "Do you want to start the stack now? [y/N]: " start_now
    if [[ "$start_now" =~ ^[yY]$ ]]; then
        install_stack
    else
        log_info "You can start your stack again later using Option 1 or 3."
    fi
}


function view_logs() {
  if [[ ! -d "$STACK_DIR" ]]; then
    log_error "Stack directory not found. Is the stack installed?"
    return
  fi
  log_info "Showing live logs for all services. Press CTRL+C to stop."
  (cd "$STACK_DIR" && docker compose logs -f)
}

function prune_docker() {
  log_warn "!!! WARNING !!!"
  log_warn "This will remove all stopped containers, unused networks, dangling images,"
  log_warn "and the build cache. This can free up a lot of space but is irreversible."
  read -p "Are you sure you want to prune the Docker system? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    log_info "Aborting."
    return
  fi
  docker system prune -a -f
  log_info "Docker system prune complete."
}

function destroy_config_folders() {
    log_warn "--- Starting Local Volume DESTRUCTION ---"
    log_warn "!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!"
    log_warn "This is a highly destructive and IRREVERSIBLE action."
    log_warn "This will permanently delete ALL LOCAL DOCKER VOLUMES associated with this stack."
    echo ""
    read -p "To confirm, type the word 'DESTROY' and press Enter: " confirm_destroy

    if [[ "$confirm_destroy" != "DESTROY" ]]; then
        log_info "Confirmation failed. Aborting."
        return
    fi

    log_info "Confirmation received. Stopping stack and removing all volumes..."
    # The 'down -v' command is the correct way to do this for named volumes.
    (cd "$STACK_DIR" && docker compose down -v)
    log_info "--- Local Volume Destruction Complete ---"
}


# --- Main Script Logic ---
function main() {
  # Root check for operations that require it
  if [[ $EUID -ne 0 ]]; then
    log_warn "This script has functions that require root privileges."
    log_warn "Please run with 'sudo' for full functionality."
  fi

  # Check for lock file
  if [[ -e "$LOCK_FILE" ]]; then
    log_fatal "Lock file $LOCK_FILE exists. Another instance may be running. Aborting."
  fi
  echo $$ > "$LOCK_FILE"

  check_dependencies

  while true; do
    show_menu
    read -p "Enter your choice [0-8]: " choice

    # Clear screen after choice for better UX
    tput clear || clear

    case "$choice" in
      1) install_stack ;;
      2) uninstall_stack ;;
      3) reload_stack ;;
      4) backup_configs ;;
      5) restore_configs ;;
      6) view_logs ;;
      7) prune_docker ;;
      8) destroy_config_folders ;;
      0) log_info "Exiting. Goodbye!"; break ;;
      *) log_error "Invalid option. Please try again." ;;
    esac

    if [[ "$choice" != "0" ]]; then
      read -n 1 -s -r -p "Press any key to return to the menu..."
      echo ""
      tput clear || clear
    fi
  done
}

# Start the script
main "$@"
