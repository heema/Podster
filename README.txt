
NAME: podster - podcatching client

SYNOPSIS
podster [OPTIONS]

DESCRIPTION
This is a podcatcher script that will prompt you to either download or listen (stream) to the latest podcasts and it will remember the podcasts that you have downloaded so that you only listen to the new shows.

It detects BitTorrent files and opens them with the appropriate client that’s specified in the script

you must first make a text file in the main directory and name the text file podlist.txt

OPTIONS
-a, --archive		Copies the podcasts to a specified location
-n, --podcast_number	Specify the number of podcast per each stream to be downloaded
-C, --config		Specifiy a file which contains variables that will override the default values
-m, --manage_feeds	Lets you add , delete and check the status of the feeds
-c, --clean		Delete the podcasts and playlist
-p, --play		Play the playlist
-d, --download		Downloads automatically new podcasts
-l, --download_limit	Limit the download speed to amount bytes per second. Amount is expressed in kilobytes, For example --download_limit 20 will limit the retrieval rate to 20KB/s
-f, --full-catalogue	Adds the previous podcasts to your history without downloading them
-h, --help		Display this text and exit

FILES
podlist.txt, downloaded_history.txt

EXAMPLES
podster -n 1              Will download the latest podcasts
podster -n 1 -d           Will download the latest podcasts without confirmation

AUTHOR
Heema
