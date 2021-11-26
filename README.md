# gdrive-rclone-docker

![GitHub](https://img.shields.io/github/license/controlol/gdrive-rclone-docker)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/controlol/gdrive-rclone-docker/Publish%20Docker%20Tag?logo=docker)
![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/controlol/gdrive-rclone)
![GitHub top language](https://img.shields.io/github/languages/top/controlol/gdrive-rclone-docker?color=green)
![GitHub milestone](https://img.shields.io/github/milestones/progress/controlol/gdrive-rclone-docker/4?label=Milestone%20V1)

## Introduction

This Docker image is used to mount to your Google Drive folder to a local folder. All files will appear as if they are locally on your system and you can browse like you normally would. Added files will at first be stored locally and pushed to Google Drive once per 6 hours. This will allow quick access to newly created files. Secondly there is a configurable cache pool to further improve the experience.

If you want to use the Google Drive space on your local network you can share the mounted folder as a SMB or NFS share.

## Usage
This image will require some special flags to function properly, this is because you will be mounting mergefs (fuse) to a shared docker volume. Add the following flags to you docker cli `--cap-add SYS_ADMIN --device /dev/fuse`.

To Use Rclone with Google Drive you will need to allow access to your Google Drive API.

#### Prerequisites
You will need to have rclone installed on your machine or in a temporary docker container. Obtain a Google Drive API client id and secret following [this guide from Rclone](https://rclone.org/drive/#making-your-own-client-id). Somewhere in your drive you will need to create a root folder for you Rclone files to live. I would suggest calling it rclone. The RCLONE_FOLDER will live inside this folder. Open the folder in Google Drive and copy the folder id.

<img src="https://github.com/controlol/gdrive-rclone-docker/raw/master/readme/folder_id.jpg" alt="Copy folder id" width="700"/>

#### Create base rclone configuration

Once you have the client id, client secret and folder id you can run the command `rclone config`, this will prompt you with a couple of questions.
```
n - Creates a new remote
gdrive - Give your new remote a name, same as RCLONE_REMOTE
drive - Selects Google Drive
client_id - Enter the client ID you obtained previously
client_secret - Enter the client secret you obtained previously
1 - Enables access to the entire drive
root_folder_id - Enter your folder id from the created folder before
service_account_file - Leave blank and continue
y - Edit adavnce config
```

After this you want to keep clicking enter and use default options until you reach:
```
Remote config
Use auto config?
 * Say Y if not sure
 * Say N if you are working on a remote or headless machine
y) Yes (default)
n) No
```

Unless you are running the command on a PC with a browser you will want to choose `no`. It will give you a link you can paste in your browser. Take the steps and allow access to the folder. Once finished you will get a code and paste this in de Rsync terminal. Continue with the last two options.

```
n - Do not configure as team drive.
y - Accept the config.
```

Using the command rclone config file, you will get the location of the created config file. Copy this file to the folder where you plan to mount the config folder of the container and name the file `gdrive-rclone.conf`. This config will be used as a base configuration. The encrypted remote will be added automatically once you start the container.

### Docker CLI
```bash
docker run -d \
  --name=gdrive-rclone \
  --net=bridge \
  -e TZ=Europe/Amsterdam \
  -e PASSWORD=yourpassword \
  -e PASSWORD2=yourpassword \
  -e RCLONE_FOLDERS=remote1,crypt,move;remote2,nocrypt,copy \
  -e RCLONE_REMOTE=yourremote \
  -e CACHE_MAX_SIZE=250G \
  -e CACHE_MAX_AGE=12h \
  -v /path/to/config:/config \
  -v /path/to/localstorage:/local \
  -v /path/to/remote:/remote:rw,shared \
  --cap-add SYS_ADMIN --device /dev/fuse \
  --restart unless-stopped \
  controlol/gdrive-rclone
```

### Volumes

| Container path | Description | Type |
| ---  | --- | --- |
| /config | Contains the rclone configuration files | normal |
| /local  | Contains the local files that have to be uploaded | normal |
| /remote | Use this folder to view and upload files | shared |

Make sure you have [created the rclone base configuration](#create-base-rclone-configuration) and copied it to /config/gdrive-rclone.conf.<br/>
The /local directory contains two folders, gdrive and cache. The gdrive folder is temporary storage for files that were copied to /remote but still have to be uploaded to Google Drive. The cache folder has temporarily downloaded files from gdrive, and will not grow beyond CACHE_MAX_SIZE. Each remote will have it's own subdirectory inside the cache and gdrive folder.

#### File uploads
Every six hours files will be moved to Google Drive, a file is only considered if it is older than 6 hours
| File Age | Result |
| --- | --- |
| 0H < Created < 6H | Not uploaded |
| 6H < Created < 12H | Uploaded |
| 12H < Created | Upload limit reached or upload speed too slow<br> Upload will be retried during the next run |

### Environment

| Paramater | Function | Example |
| --- | --- | --- |
| RCLONE_FOLDERS | The name of the remote subfolder you want to use | media,crypt,move; |
| RCLONE_REMOTE | The name of your [created rclone drive remote](#create-base-rclone-configuration) | gdrive |
| PASSWORD | The password to encrypt your files | 64-128 char |
| PASSWORD2 | The password salt to encrypt your files | 64-128 char |
| CACHE_MAX_SIZE | The maximum size of cache | 250G |
| CACHE_MAX_AGE | How long cache should be kept | 12h |
| ENABLE_WEB | If not empty the WebUI is enabled | "yes" or "" |
| RC_WEB_USER | The username for the WebUI | user |
| RC_WEB_PASS | The password for the WebUI | password |
| RC_WEB_URL | Custom weburl to a github api release endpoint | url |
| PUID | The user id to take ownership of the files | 1000 |
| PGID | The group id to take ownership of the files | 100 |
| UMASK | The password for the WebUI | 000 |
| TZ | The timezone of the container | Europe/Amsterdam |

The RCLONE_FOLDERS environment can be used to create one or more remotes. Each remote is seperated by a semicolon, settings for the remote as seperated with a comma. There are two settings. You can skip one or both options, the default value will be used.
The first setting is used to enable encryption of the uploaded folder, if you want to encrypt the uploaded folder enter `crypt` as the value.
The second setting determines the command you want to use to upload, the default value is `move`. However you can choose `copy` if you want to keep all the files locally as well.

#### Rclone remote examples
| Option | Valid values | Default |
| --- | --- | --- |
| crypt | `crypt`, `nocrypt` | `nocrypt` |
| command | `copy`, `move` | `move` |

## Mounting a remote volume to another container
It is possible to use the remote folder in other containers. The easiest way would be to directly mount one (or more) of the subfolders directly to the container. However this will not work when the gdrive-rclone container is restarted. Therefor it is recommended to mount the remote parent folder directly in slave mode. This will give the container access to all of your mounts.

### Example
First option:
```bash
docker run -d \
  -e FOLDERS=remote1,nocrypt,move \
  -v /path/to/remote:/remote \
  --cap-add SYS_ADMIN --device /dev/fuse \
  controlol/gdrive-rclone:latest
  
docker run -d \
  -v /path/to/remote/remote1:/container/path/remote1
  ubuntu:latest
```
The Ubuntu container needs to be restarted after the gdrive-rclone container has restarted.

Second option:
```bash
docker run -d \
  -e FOLDERS=remote1,nocrypt,move \
  -v /path/to/remote:/remote \
  --cap-add SYS_ADMIN --device /dev/fuse \
  controlol/gdrive-rclone:latest
  
docker run -d \
  -v /path/to/remote:/container/path:slave
  ubuntu:latest
```
The Ubuntu container does not have to be restarted after gdrive-rclone has restarted. After the gdrive-rclone container's state is up the subdirectories will work again.

By no means are these examples complete with all the necessary volumes and environments but it shows a basic example how the folder structure works.


## Notes
It is recommended to use a random string for PASSWORD and PASSWORD2 between 64 and 128 characters, they should not be the same string.<br/>
Your CACHE_MAX_SIZE should be at least as the size as the largest file you expect to upload.<br/>
Setting USE_COPY will allow you to keep the files locally, they will still be uploaded on the same schedule.<br/>
A move job will not run for longer than 6h to prevent multiple jobs running at once.<br/>
The maximum upload limit is 750GB per day.
