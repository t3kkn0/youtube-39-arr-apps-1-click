
# My Custom ARR Media Stack

This document outlines the setup and configuration for a comprehensive media automation stack using Docker. This setup is customized to include dedicated libraries for Movies, TV Shows, and Anime, all managed through specific applications and served via Emby.

## Table of Contents

1.  [One-Time Server Setup](https://www.google.com/search?q=%231--one-time-server-setup)
2.  [Managing the Stack](https://www.google.com/search?q=%232--managing-the-stack)
3.  [Initial Application Configuration](https://www.google.com/search?q=%233--initial-application-configuration)

-----

## 1\. One-Time Server Setup

These steps only need to be performed once when first deploying the project on your server.

### Step 1.1: Clone Your Private Repository

Clone **your own private repository** (not the public template) to your server. This command will download your `docker-compose.yml` and your custom `.ovpn` files.

```bash
# Replace with the actual URL from your private GitHub repo
git clone https://github.com/YourUsername/your-private-repo.git
```

### Step 2.2: Create the Directory Structure

This command will create all the necessary folders on your NAS for your applications' configurations and media. It's safe to run even if some folders already exist.

```bash
# Creates all folders on your NAS share
sudo mkdir -p \
/mnt/NAS-DATA/Downloads/complete \
/mnt/NAS-DATA/Downloads/incomplete \
/mnt/NAS-DATA/nzbget/config \
/mnt/NAS-DATA/qbittorrent/config \
/mnt/NAS-DATA/rdt-client/config \
/mnt/NAS-DATA/Prowlarr/config \
/mnt/NAS-DATA/Prowlarr/backup \
/mnt/NAS-DATA/Sonarr/config \
/mnt/NAS-DATA/Sonarr/backup \
/mnt/NAS-DATA/Sonarr/tvshows \
/mnt/NAS-DATA/Radarr/config \
/mnt/NAS-DATA/Radarr/backup \
/mnt/NAS-DATA/Radarr/movies \
/mnt/NAS-DATA/Bazarr/config \
/mnt/NAS-DATA/Homarr/configs \
/mnt/NAS-DATA/Homarr/data \
/mnt/NAS-DATA/Homarr/icons \
/mnt/NAS-DATA/JellySeerr/config \
/mnt/NAS-DATA/Emby/config \
/mnt/NAS-DATA/Sonarr-Anime/config \
/mnt/NAS-DATA/Sonarr-Anime/anime



DESTROY FOLDERS!!!!!!!


sudo rm -rf \
/mnt/NAS-DATA/Downloads/complete \
/mnt/NAS-DATA/Downloads/incomplete \
/mnt/NAS-DATA/nzbget/config \
/mnt/NAS-DATA/qbittorrent/config \
/mnt/NAS-DATA/rdt-client/config \
/mnt/NAS-DATA/Prowlarr/config \
/mnt/NAS-DATA/Prowlarr/backup \
/mnt/NAS-DATA/Sonarr/config \
/mnt/NAS-DATA/Sonarr/backup \
/mnt/NAS-DATA/Sonarr/tvshows \
/mnt/NAS-DATA/Radarr/config \
/mnt/NAS-DATA/Radarr/backup \
/mnt/NAS-DATA/Radarr/movies \
/mnt/NAS-DATA/Bazarr/config \
/mnt/NAS-DATA/Homarr/configs \
/mnt/NAS-DATA/Homarr/data \
/mnt/NAS-DATA/Homarr/icons \
/mnt/NAS-DATA/JellySeerr/config \
/mnt/NAS-DATA/Emby/config \
/mnt/NAS-DATA/Sonarr-Anime/config \
/mnt/NAS-DATA/Sonarr-Anime/anime

# Enter your project directory (use the actual name of your repo)
cd your-private-repo

# Create the gluetun config folder here
mkdir gluetun-config

# Move your OVPN files into it (if they aren't already)
mv *.ovpn gluetun-config/
```

### Step 2.3: Set Folder Ownership

This command ensures the applications running in Docker have permission to read and write to your NAS storage. It uses the `PUID` and `PGID` from your `.env` file.

```bash
sudo chown -R 1000:1000 /mnt/NAS-DATA/
```

### Step 2.4: Create the Local Secrets File

While inside your project directory, create the `.env` file that will contain all your passwords and IDs. This file is ignored by Git and will **never** be uploaded to GitHub.

1.  Create and open the file: `nano .env`
2.  Paste the following content, replacing the placeholder values:
    ```ini
    # Main path for all ARR apps
    ARRPATH=/mnt/NAS-DATA/

    # Global Variables
    PUID=1000
    PGID=1000
    TZ=Europe/Warsaw

    # --- Gluetun VPN Credentials ---
    OPENVPN_USER=YOUR-FASTVPN-USERNAME-HERE
    OPENVPN_PASSWORD=YOUR-FASTVPN-PASSWORD-HERE
    ```
3.  Save and exit (`Ctrl + X`, then `Y`, then `Enter`).

-----

## 2\. Managing the Stack

All commands must be run from inside your project directory (e.g., `/home/marek/your-private-repo`).

  * **Start all services:**

    ```bash
    docker compose up -d
    ```

  * **Stop all services:**

    ```bash
    docker compose down
    ```

  * **Check the logs of a specific service:**

    ```bash
    docker compose logs -f qbittorrent
    ```

    *(Replace `qbittorrent` with any other service name. The `-f` flag follows the log in real-time.)*

  * **Update your applications:**

    ```bash
    docker compose pull && docker compose up -d
    ```

    *(This pulls the latest versions of all images and restarts the containers.)*

-----

## 3\. Initial Application Configuration

After starting the stack for the first time, you need to configure each service.

> **IMPORTANT NETWORKING NOTE:**
> In our setup, only the download clients (`qbittorrent`, `nzbget`) are on the VPN network. All other apps (`prowlarr`, `sonarr`, `radarr`, etc.) are on the default Docker network. This means that when one application needs to talk to another, you **must use your server's main IP address** (e.g., `192.168.1.100`). Do not use `localhost` or the container name. You can find your server's IP by running the `ip a` command.

Access each service below by replacing `YOUR_SERVER_IP` with your actual server IP address.

-----

### **qBittorrent**

  * **URL:** `http://YOUR_SERVER_IP:8080`

<!-- end list -->

1.  **Find Temp Password:** Check the logs to get your initial password: `docker compose logs qbittorrent`. Look for the temporary password line. The username is `admin`.
2.  **Log In & Change Password:** Go to `Tools -> Options... -> Web UI` and set a new, permanent username and password.
3.  **Set Download Paths:** Go to the `Downloads` tab:
      * **Default Save Path:** `/downloads/complete`
      * Check **Keep incomplete torrents in:** and set the path to `/downloads/incomplete`
4.  Click **Save**.

-----

### **Prowlarr**

  * **URL:** `http://YOUR_SERVER_IP:9696`

<!-- end list -->

1.  **Setup:** Set a username and password on first launch.
2.  **Add Download Client:**
      * Go to `Settings -> Download Clients` and click `+` to add a new one.
      * Choose **qBittorrent**.
      * **Host:** Enter your server's IP address (e.g., `192.168.1.100`).
      * **Port:** `8080`
      * Enter the username and password you just set for qBittorrent.
      * Click `Test` to ensure it works, then `Save`.
3.  **Add Indexers:** Go to the `Indexers` page and add your preferred torrent indexer sites.

-----

### **Sonarr (for TV Shows)**

  * **URL:** `http://YOUR_SERVER_IP:8989`

<!-- end list -->

1.  **Connect Download Client:** Go to `Settings -> Download Clients`, add qBittorrent, and configure it exactly as you did in Prowlarr (using the server IP).
2.  **Add Root Folder:** Go to `Settings -> Media Management` and add a Root Folder pointing to `/data/tvshows`.
3.  **Connect to Prowlarr:** Go to `Settings -> Indexers`, click `+`, choose `Add Indexer from Prowlarr`, and follow the prompts.

-----

### **Sonarr-Anime (for Anime)**

  * **URL:** `http://YOUR_SERVER_IP:8990`

<!-- end list -->

1.  **Connect Download Client:** Repeat the same steps as the first Sonarr to connect to qBittorrent (using the server IP).
2.  **CRITICAL ANIME SETTING:** Go to `Settings -> Media Management`. Click **"Show Advanced"** at the top. Under the "Series" section, change the **Series Type** from "Standard" to **"Anime"**. This is essential for correct processing.
3.  **Add Root Folder:** Add a Root Folder pointing to `/data/anime`.
4.  **Connect to Prowlarr:** Connect this Sonarr instance to Prowlarr just like you did with the first one.

-----

### **Radarr (for Movies)**

  * **URL:** `http://YOUR_SERVER_IP:7878`
  * Follow the same logic as Sonarr: connect your download client (qBittorrent via server IP), set your Root Folder to `/data/movies`, and connect to Prowlarr for indexers.

-----

### **Emby**

  * **URL:** `http://YOUR_SERVER_IP:8096`

<!-- end list -->

1.  **First-Time Setup:** Walk through the initial setup wizard to create your admin user.
2.  **Add Your Libraries:**
      * In the Emby dashboard, go to `Settings (the gear icon) -> Library`.
      * Click **+ Add Library**.
      * **For TV Shows:** Select "TV Shows" as content type, name it "TV Shows", and add the folder path `/data/tvshows`.
      * **For Movies:** Select "Movies" as content type, name it "Movies", and add the folder path `/data/movies`.
      * **For Anime:** Select "TV Shows" as content type, name it "Anime", and add the folder path `/data/anime`.

-----

### **Other Services**

  * **Homarr (Dashboard):** `http://YOUR_SERVER_IP:7575`
  * **Bazarr (Subtitles):** `http://YOUR_SERVER_IP:6767`
  * **Jellyseerr (Requests):** `http://YOUR_SERVER_IP:5055`
  * **RDT-Client (Real-Debrid):** `http://YOUR_SERVER_IP:6500`












############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################

### Useful Links:
- [Servarr Wiki](https://wiki.servarr.com/)
- [Trash Guides](https://trash-guides.info/)
- [Ascii ART](https://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow)

### Download and unzip Files from GitHub:

git clone https://github.com/t3kkn0/youtube-39-arr-apps-1-click.git

cd my-private-arr-stack

nano .env

OPENVPN_USER=YOUR_FASTVPN_USERNAME
OPENVPN_PASSWORD=YOUR_FASTVPN_PASSWORD

Ctrl + X 


https://github.com/automation-avenue/youtube-39-arr-apps-1-click <br />
cd /home/marek/Downloads <br />
unzip youtube-39-arr-apps-1-click <br />

### Installation process:
Make sure you are in the same folder as docker-compose.yml and .env file, then 'up' to deploy, 'stop' and 'rm' to stop and remove the stack  :<br />

```bash
sudo docker-compose up -d 
sudo docker-compose stop
sudo docker-compose rm 
```

Chage ownership of the folder specified in .env file (by default its /media/Arr) and 
run 'chown' command with the user id and group id configured in that .env file:<br />
`chown -R 1000:1000 /media/Arr`<br />
Now you can log on and work with all services.<br />

First configure the qBittorrent service because its using temporary password only:<br />

**qBittorrent:**<br />
Check logs for qbittorrent container:<br />
`sudo docker logs qbittorrent`<br />
You will see in the logs something like:<br />
*The WebUI administrator username is: admin<br />
The WebUI administrator password was not set. A temporary password is provided for this session: <your-password-will-be-here>* <br />
Now you can go to URL:<br />
http://localhost:8080<br />
and log on using details provided in container logs.<br />
Go to Tools - Options - WebUI - change the user and password and tick 'bypass authentication for clients on localhost' .<br />

Then configure Prowlarr service (each of these services will require to set up user/pass):<br />

**Prowlarr:**<br />
http://localhost:9696<br />
Go to Settings - Download Clients - `+` symbol - Add download client - choose qBittorrent (unless you decided touse different download client)<br />
Put the port id matching the WebUI in docker-compose for qBittorrent (default is 8080) and username and password that you configured for qBittorrent in previous step<br />
Host - you might want to change from 'localhost'to ip address of the host machine (run 'ip address' command on your host system)<br />
or to 'qbittorrent' - click little 'Test' button at the bottom before saving to make sure you get a green 'tick'.<br />

**Sonarr:**<br />
http://localhost:8989<br />
Go to Settings - Media Management - Add Root Folder - set your root folder to what is on the right side of the colon<br />
in 'volume' config line for Sonarr - in our file its {ARRPATH}Sonarr/tvshows:/data/tvshows<br />
so set '/data/tvshows' as your root folder.<br />
Go to Settings - Download Clients - click `+` symbol - choose qBittorrent and repeat the steps from Prowlarr.<br />
Go to Settings - General - scroll down to API key - copy - go to Prowlarr - Settings - Apps -click '+' - Sonarr - paste  API key. <br />
You might also have to  change 'localhost' to ip address of the Ubuntu/Host - use 'Test' button below to see if you get green 'tick'.<br />
Then Settings - General - switch to 'show advanced' in top left corner - scroll down to 'Backups' and choose /data/Backup (or whatever <br />
location you have in your docker compose file for Sonarr backups- we have ${ARRPATH}Sonarr/backup:/data/Backup hence we set /data/Backup )<br />
as you have to choose again whatever is there on the right side from the colon <br />

**Radarr:**<br />
http://localhost:7878<br />
Go to Settings - Media Management - Add Root Folder - set  /data/movies as your root folder <br />
Then Settings- Download clients - click 'plus' symbol, choose qBittorrent etc - basically same steps as for Sonarr<br />
Settings - General - scroll down to API key - copy - go to Prowlarr - add same way as in sonarr<br />
Settings - General - switch to 'show advanced'- Backups - choose /data/Backup folder <br />

**Lidarr:**<br />
http://localhost:8686<br />
Follow the same steps for Lidarr and Readarr as for above applications.<br />

**Readarr:**<br />
http://localhost:8787<br />

**Homarr:**<br />
http://localhost:7575<br />

Now go back to Prowlarr and click 'Indexers at the top right, click 'Add indexer' - search for sth like 'rarbg' or 'yts' etc then test - save<br />
Then click 'Sync App Indexers  icon (next to 'Add indexer')<br />
If you go to Settings - Apps - you should see green 'Full sync' next to each application.<br />
Arr stack completed - you can now 'add movie' in radarr or 'add series' in sonarr etc and click 'search all' or 'search monitored' - that will trigger the download process.<br />

**Jellyfin:**<br />
http://localhost:8096<br />
If you run `docker-compose up` and have something running on port 1900 -  its most possibly rygel service, run:<br />
`sudo apt-get remove rygel` and run the `sudo docker-compose up -d` again.<br />
Then add media library in Jellyfin  matching folders configured in docker-compose.yml file, so in Jellyfin you should see them as: <br />
/data/Movies <br />
/data/TVShows <br />
/data/Music <br />
/data/Books <br />

That might depend on the image, you basically match the right side of the config in Jellyfin's 'volume' configuration. <br />
If the volume configuration looks like that: <br />
```
    volumes:
      - ${ARRPATH}Radarr/movies:/data/Movies
      - ${ARRPATH}Sonarr/tvshows:/data/TVShows
      - ${ARRPATH}Lidarr/music:/data/Music
      - ${ARRPATH}Readarr/books:/data/Books
```
then on the container you match that right side from the colon ( /data/Movies, /data/TVShows etc )<br />





CREATING FOLDER STRUCTURE ON NAS:


sudo mkdir -p \
/mnt/NAS-DATA/Bazarr/config \
/mnt/NAS-DATA/Downloads/complete \
/mnt/NAS-DATA/Downloads/incomplete \
/mnt/NAS-DATA/Emby/config \
/mnt/NAS-DATA/Homarr/configs \
/mnt/NAS-DATA/Homarr/data \
/mnt/NAS-DATA/Homarr/icons \
/mnt/NAS-DATA/JellySeerr/config \
/mnt/NAS-DATA/Prowlarr/backup \
/mnt/NAS-DATA/Prowlarr/config \
/mnt/NAS-DATA/Radarr/backup \
/mnt/NAS-DATA/Radarr/config \
/mnt/NAS-DATA/Radarr/movies \
/mnt/NAS-DATA/Sonarr/backup \
/mnt/NAS-DATA/Sonarr/config \
/mnt/NAS-DATA/Sonarr/tvshows \
/mnt/NAS-DATA/Sonarr-Anime/anime \
/mnt/NAS-DATA/Sonarr-Anime/config \
/mnt/NAS-DATA/nzbget/config \
/mnt/NAS-DATA/qbittorrent/config \
/mnt/NAS-DATA/rdt-client/config


