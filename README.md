
# Arr-Stack: Your Automated Media Server

Welcome to Arr-Stack! This project provides a comprehensive, pre-configured media automation stack using Docker. It handles everything from downloading to organizing your movies, TV shows, and anime, all managed by a simple, user-friendly script.

This guide will walk you through the entire process, from installation to final configuration.

## Core Features

The included management script automates almost everything for you:

* **One-Line Installation:** A single command downloads the manager and starts the setup.
* **Menu-Driven Interface:** No need to memorize complex Docker commands. Just choose an option from the menu.
* **Guided Setup:** The script handles creating folders, setting permissions, and managing configuration files.
* **Safe Operations:** Before potentially destructive actions like uninstalling or updating, the script will offer to create a backup of your settings for easy recovery.
* **Easy Management:** Reloading, updating, viewing logs, and other maintenance tasks are all available as simple menu options.

---

## Step 1: Installation

Getting started is as simple as running one command. Open your server's terminal, paste the following line, and press Enter.

```bash
curl -L -o manage-arr.sh https://raw.githubusercontent.com/t3kkn0/Arr-Stack/main/manage-arr.sh && chmod +x manage-arr.sh && sudo ./manage-arr.sh
```

This command will:
1.  Download the latest version of the management script (`manage-arr.sh`).
2.  Make it executable.
3.  Run it with `sudo` (required for Docker and file management).

You will then be greeted by the main menu, where you will select **Option 1: Install Stack** to begin the guided setup.

---

## Step 2: Using the Management Menu

Once installed, you can run `sudo ./manage-arr.sh` at any time to access the main menu. Here’s what each option does:

* **1. Install Stack:** Performs the initial installation. It clones the project, sets up your `.env` configuration file, prepares NAS folders, and starts all the services. If you already have a backup, you'll be offered the chance to restore it here.
* **2. Uninstall Stack:** Stops and removes the application containers. It will ask you if you want to keep your application data (safer) or delete it completely. It will also offer to create a final backup before deleting anything.
* **3. Reload Stack:** This is how you update your stack. It pulls the latest application images and configuration from GitHub and restarts your services. It will offer to create a backup before it starts, just in case an update causes issues.
* **4. Backup Configuration:** Manually creates a full backup of your local application settings and your `.env` file to your NAS.
* **5. Restore Configuration:** Restores your settings from a previously created backup. This is great for migrating to a new server or recovering from an error.
* **6. View Live Logs:** Shows you the real-time logs from all running applications, which is useful for troubleshooting.
* **7. Prune Docker System:** A housekeeping tool to remove unused Docker data and free up disk space.
* **8. DESTROY Config Folders:** A highly destructive option that completely removes all local application data. Use with extreme caution.

---

## Step 3: Initial Application Setup

After the stack is running, you need to configure each application to work together.

> **IMPORTANT NETWORKING NOTE:**
> When one application needs to talk to another (e.g., connecting Sonarr to qBittorrent), you **must use your server's main IP address** (`10.20.10.52`). Do not use `localhost`.

### **qBittorrent (Download Client)**

* **URL:** `http://10.20.10.52:8080`

1.  **Find Temp Password:** The first time you run the stack, a temporary password is created. Check the logs to get it by choosing **Option 6** in the manager menu. The username is `admin`.
2.  **Log In & Change Password:** Go to `Tools -> Options... -> Web UI` and set a new, permanent username and password.
3.  **Set Download Paths:** Go to the `Downloads` tab:
    * **Default Save Path:** `/downloads/complete`
    * Check **Keep incomplete torrents in:** and set the path to `/downloads/incomplete`
4.  Click **Save**.

### **Prowlarr (Indexer Manager)**

* **URL:** `http://10.20.10.52:9696`

1.  **Setup:** Set a username and password on first launch.
2.  **Add Download Client:**
    * Go to `Settings -> Download Clients` and click `+` to add a new one.
    * Choose **qBittorrent**.
    * **Host:** `10.20.10.52`
    * **Port:** `8080`
    * Enter the username and password you just set for qBittorrent.
    * Click `Test` to ensure it works, then `Save`.
3.  **Add Indexers:** Go to the `Indexers` page and add your preferred torrent indexer sites. Some indexers are protected by Cloudflare; for those, you will need Flaresolverr.
4.  **Connect Flaresolverr:** Go to `Settings -> Indexers`, click `Add Indexer`, choose one that requires solving a CAPTCHA (like some public trackers), and scroll down to the "FlareSolverr" section. Enter the URL: `http://flaresolverr:8191`. Test and save. Prowlarr will now use it automatically for relevant indexers.

### **Sonarr (for TV Shows)**

* **URL:** `http://10.20.10.52:8989`

1.  **Connect Download Client:** Go to `Settings -> Download Clients`, add qBittorrent, and configure it exactly as you did in Prowlarr.
2.  **Add Root Folder:** Go to `Settings -> Media Management` and add a Root Folder pointing to `/tv`.
3.  **Connect to Prowlarr:** Go to `Settings -> Indexers`, click `+`, choose `Add Indexer from Prowlarr`, and follow the prompts.

### **Sonarr-Anime (for Anime)**

* **URL:** `http://10.20.10.52:8990`

1.  **Connect Download Client:** Repeat the same steps as the first Sonarr to connect to qBittorrent.
2.  **CRITICAL ANIME SETTING:** Go to `Settings -> Media Management`. Click **"Show Advanced"** at the top. Under the "Series" section, change the **Series Type** from "Standard" to **"Anime"**. This is essential for correct processing.
3.  **Add Root Folder:** Add a Root Folder pointing to `/anime`.
4.  **Connect to Prowlarr:** Connect this Sonarr instance to Prowlarr just like you did with the first one.

### **Radarr (for Movies)**

* **URL:** `http://10.20.10.52:7878`
* Follow the same logic as Sonarr: connect your download client, set your Root Folder to `/movies`, and connect to Prowlarr for indexers.

### **Bazarr (for Subtitles)**

* **URL:** `http://10.20.10.52:6767`
* Bazarr finds subtitles for the media in your Radarr and Sonarr libraries.

1.  **Go to `Settings -> Sonarr`:**
    * Enable it and enter the Sonarr details:
    * **Host:** `sonarr` (you can use the container name here)
    * **Port:** `8989`
    * **API Key:** Get this from Sonarr under `Settings -> General`.
    * Repeat this for Sonarr-Anime on a new entry, using `sonarr-anime` as the host and port `8989`.
2.  **Go to `Settings -> Radarr`:**
    * Enable it and enter the Radarr details (host `radarr`, port `7878`, and API key from Radarr).
3.  **Go to `Settings -> Languages`:**
    * Configure your desired languages for subtitles.

### **Emby (Media Server)**

* **URL:** `http://10.20.10.52:8096`

1.  **First-Time Setup:** Walk through the initial setup wizard to create your admin user.
2.  **Add Your Libraries:**
    * In the Emby dashboard, go to `Settings (the gear icon) -> Library`.
    * Click **+ Add Library**.
    * **For TV Shows:** Select "TV Shows," name it "TV Shows," and add the folder path `/data/tvshows`.
    * **For Movies:** Select "Movies," name it "Movies," and add the folder path `/data/movies`.
    * **For Anime:** Select "TV Shows," name it "Anime," and add the folder path `/data/anime`.

### **Jellyseerr (Requests Manager)**

* **URL:** `http://10.20.10.52:5055`
* Jellyseerr allows users to request new media, which is then automatically searched for by Sonarr/Radarr.

1.  **Walk through the setup wizard.**
2.  **Connect to Emby:** When prompted, choose Emby as your media server.
    * **Emby Hostname:** `emby`
    * **Port:** `8096`
    * **API Key:** In Emby, go to `Settings -> API Keys` to generate one.
3.  **Connect to Radarr & Sonarr:** Add your Radarr and Sonarr instances using their container names (`radarr`, `sonarr`, `sonarr-anime`) and their API keys. This allows Jellyseerr to send requests to them.

### **Homarr (Dashboard)**

* **URL:** `http://10.20.10.52:7575`
* Homarr is a dashboard to keep all your service URLs in one place.

1.  **Click the "Enter Edit Mode" toggle** at the top right.
2.  Click the `+` button to add new tiles for each of your services (Sonarr, Radarr, etc.), using their URLs from this guide.
3.  Drag and drop the tiles to organize your dashboard as you see fit.

### **Other Service Information**

* **Flaresolverr:** This service runs in the background and has no user interface. Its job is to bypass Cloudflare protection for Prowlarr. You configure it in Prowlarr, as described above.
* **Nzbget:** An alternative downloader for Usenet. If you use it, its URL is `http://10.20.10.52:6789`. Configuration is similar to qBittorrent (set download paths).

---

## Optional: Installing Portainer (Container Manager)

If you want a graphical interface to see and manage your Docker containers, Portainer is a great tool. This is not part of the Arr-Stack but is easy to add. Run these commands on your server:

1.  **Create a volume for Portainer's data:**
    ```bash
    sudo docker volume create portainer_data
    ```

2.  **Run the Portainer container:**
    ```bash
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
    ```
3.  **Access and setup Portainer:**
    * Open your browser to `https://10.20.10.52:9443`.
    * You will be prompted to create an admin user and password.
    * Once logged in, choose to manage the "Local" Docker environment, and you will see all your running Arr-Stack containers.
