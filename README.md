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


