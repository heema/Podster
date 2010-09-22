#!/bin/bash

#####################################################
# Podcatcher Script
#
# you must first make a text file in the main directory
# and name the text file podlist.txt
# 
# Made By : Ibrahim Riad (Heema)
# http://sites.google.com/site/heematux/
#
# Dependencies : wget , awk , sed , xmlstarlet or xsltproc
#
# Some code was inspired from bashpodder
# http://linc.homeunix.org:8080/scripts/bashpodder/
#
# last update : 14-09-2010
VER=1.7.8
#
#####################################################

#####################################################
# Declaring variables
#####################################################

main_directory="$HOME/Podcast"
download_directory="$main_directory/shows"
archive_directory="$main_directory/Archive"
PODLIST="$main_directory/podlist.txt"
Titles="$main_directory/titles.txt"
temp_directory="$main_directory/temp"
lock="$main_directory/lock"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#NOTE: Anything in the temp_directory will be deleted
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

history="$main_directory/downloaded_history.txt"
DATESTR=`date +'%d-%m-%Y %H:%M'`
podcast_number="4"
#alarm="/usr/lib/openoffice/share/gallery/sounds/applause.wav"
multimedia_player="xmms"
stream_player="vlc"
bittorrent_client="transgui"

#<--------------------------------------------------->

# Creates a lock file to stop a second occurrence of the script
if [ -f "$lock" ];then
	echo ""
	echo -e "\033[0;31mThe script is already runing , if it isn't then delete the lock file ("$lock")\033[0m"
	echo ""
	exit 1
else
	touch "$lock"
fi

#<--------------------------------------------------->

Usage ()
{
cat <<EOF

Podster $VER
Developed by Ibrahim Riad (Heema) - http://sites.google.com/site/heematux/

Usage: $0 [OPTIONS]

Options are:
        -a, --archive                   Copies the podcasts to a specified location
        -n, --podcast_number            Specify the number of podcast per each stream to be downloaded
        -C, --config                    Specifiy a file which contains variables that will override the default values
        -m, --manage_feeds              Lets you add , delete and check the status of the feeds
        -c, --clean                     Delete the podcasts and playlist
        -p, --play                      Play the playlist
        -d, --download                  Downloads automatically new podcasts
        -l, --download_limit            Limit the download speed to amount bytes per second. Amount is expressed in kilobytes, For example, �--download_limit 20� will limit the retrieval rate to 20KB/s
        -f, --full-catalogue            Adds the previous podcasts to your history without downloading them
        -h, --help                      Display this text and exit

Examples:
        $0 -n 1                         Will download the latest podcasts
        $0 -n 1 -d                      Will download the latest podcasts without confirmation

EOF
}

#<--------------------------------------------------->

Progressbar ()
{

SOME="="
EMPTY=" "
COLUMNS=50

LEFT=$(($COLUMNS*100/20))
BAR_LENGTH=$(($(($COLUMNS*100))-$((2*$LEFT))-200))
DOT=$(($BAR_LENGTH/100))
PERCENT=$(($1*$DOT))

NUMCHARS=0

for ((j=0;$j<$LEFT;j=$j+100))
do
	echo -n " "
done
echo -n "["

for ((j=0;$j<$PERCENT;j=$j+100))
do
	echo -n "$SOME"
	NUMCHARS=$NUMCHARS+1
done

for ((j=$PERCENT;j<$BAR_LENGTH && $NUMCHARS<$((BAR_LENGTH/100));j=$j+100))
do
	echo -n "$EMPTY"
	NUMCHARS=$NUMCHARS+1
done

echo "]"
}

#<--------------------------------------------------->

DEPENDENCY_CHECK ()
{
DEPENDENCIES="wget awk sed"
 
deps_ok=YES
for dep in $DEPENDENCIES
do
    if ! which $dep &>/dev/null;  then
	echo -e "This script requires $dep to run but it is not installed"
	#echo -e "If you are running ubuntu or debian you might be able to install $dep with the following  command"
	#echo -e "\t\tsudo apt-get install $dep\n"
	deps_ok=NO
    fi
done

# Checks for xmlstarlet or xsltproc if there installed
type -P xmlstarlet &>/dev/null && PARSE_FEED="xmlstarlet tr"
type -P xsltproc &>/dev/null && PARSE_FEED="xsltproc"

if [ "$PARSE_FEED" == "" ]; then
	echo ""
	echo -e "\033[0;31mSorry, but this script requires either xmlstarlet or xsltproc and they could not be located.\033[0m"
	echo ""
	rm "$lock"
	exit 0
fi

if [[ "$deps_ok" == "NO" ]]; then
    echo -e "Unmet dependencies, Aborting!"
    exit 1
    else
	return 0
fi
}

#<--------------------------------------------------->

clean_up ()
{
# Perform program exit housekeeping
echo ""
echo ""
echo -e "\033[0;31mThe script is exiting\033[0m"
echo ""
echo -e "\033[0;31mTemp files removed\033[0m"
echo ""
sleep 1
rm "$lock"
rm "$temp_directory"/* 2>/dev/null
exit 1
}

trap clean_up SIGHUP SIGINT SIGTERM

#<--------------------------------------------------->

OPTIONS ()
{
#####################################################
# Converts long options to short ones for getopts
#####################################################

for arg
do
    delim=""
    case "$arg" in
    # translate --gnu-long-options to -g (short options)
       --podcast_number) args="${args}-n ";;
       --config) args="${args}-C ";;
       --manage_feeds) args="${args}-m ";;
       --clean) args="${args}-c ";;
       --play) args="${args}-p ";;
       --download) args="${args}-d ";;
	   --download_limit) args="${args}-l ";;
       --full-catalogue) args="${args}-f ";;
       --help) args="${args}-h ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# Reset the positional parameters to the short options
eval set -- $args

#<--------------------------------------------------->

#####################################################
# Specifying options
#####################################################

while getopts ":n:C:mcapdl:fh" option
do
    case $option in
	n)
	    # made it readonly so it cant be changed if the config is chosen first
	    readonly podcast_number="$OPTARG"
	    ;;
	C)
	    source "$OPTARG" 2> /dev/null
	    ;;
	m)
	    REFRESH_TITLES ()
	    {
	    Poslist_lines=$(wc -l "$PODLIST" | awk '{print $1}')
	    Titles_lines=$(wc -l "$Titles" | awk '{print $1}')
	    Current_titles_num=1
	    if [ ! -f "$Titles" ] || [ "$Poslist_lines" -ne "$Titles_lines" ];then
		rm "$Titles" 2>/dev/null # removes old titles to recreate it
	    for URL in `cat $PODLIST`
	    do
		echo "Please wait while downloading titles... ($Current_titles_num/$Poslist_lines)"
		TITLE=$(wget -q -O- "$URL" | xml sel -t -m '//channel' -v 'title' 2> /dev/null)
		printf "%-70s %s\n" "$URL" "$TITLE" >> "$Titles"
		Current_titles_num=$((Current_titles_num+1))
	    done
	    fi
	    }
	    REFRESH_TITLES
	    clear
	    # while loops till user chooses 0
	    while [ "$1" != "" ];do
	    printf "%-8s %-70s %s\n" "Num" "URL" "Title"
	    cat -n "$Titles"
	    echo ""
	    echo "1) Add feed"
	    echo "2) Delete feed"
	    echo "3) Edit feed list"
	    echo "4) Check status of feeds"
	    echo "5) Refresh titles"
	    echo "6) Check last update date for the feed"
	    echo ""
	    echo "0) Close"
	    echo ""
	    echo -n "Enter choise: "
	    read manage_choise
	    
	    case $manage_choise in
		1 )
		    echo -n "Enter Feed: "
		    read feed_entered
		    echo "$feed_entered" >> "$PODLIST"
		    echo "$feed_entered" >> "$Titles"
		    #clean_up
		    continue
		    ;;
		2 )
		    echo -n "Enter Number you want to delete: "
		    read number_delete
		    echo ""
		    sed -e "$number_delete"d -e '/^$/d' "$PODLIST" > "$temp_directory/podlist2.txt"
		    cp "$temp_directory/podlist2.txt" "$PODLIST"
		    sed -e "$number_delete"d -e '/^$/d' "$Titles" > "$temp_directory/Titles2.txt"
		    cp "$temp_directory/Titles2.txt" "$Titles"
		    #clean_up
		    continue
		    ;;
		3 )
		    $EDITOR "$PODLIST"
		    continue
		    ;;
		4 )
		    clear
		    for x in `cat "$PODLIST"`;do
			echo ""
			#echo -n "$x          "
			wget -t 2 -o "$temp_directory/wget_temp.txt" --spider "$x"
			wget_status=$(tail -n 2 $temp_directory/wget_temp.txt | head -n 1)
			printf "%-60s %s\n" "$x" "$wget_status"
		    done
		    clean_up
		    exit 0
		    ;;
		5 )
		    echo "Reset" > "$Titles"	# to force the titles to refresh
		    REFRESH_TITLES
		    clean_up
		    ;;
		6 )
		    echo '<?xml version="1.0"?>' > "$temp_directory/pubdate.xsl"
		    echo '<stylesheet version="1.0"' >> "$temp_directory/pubdate.xsl"
		    echo 'xmlns="http://www.w3.org/1999/XSL/Transform">' >> "$temp_directory/pubdate.xsl"
		    echo '<output method="text"/>' >> "$temp_directory/pubdate.xsl"
		    echo '<template match="/">' >> "$temp_directory/pubdate.xsl"
		    echo '<value-of select="title"/>' >> "$temp_directory/pubdate.xsl"
		    echo '<value-of select="//rss/channel/title"/><text>      </text>' >> "$temp_directory/pubdate.xsl"
		    echo '<value-of select="//rss/channel/item/pubDate"/><text>&#10;</text>' >> "$temp_directory/pubdate.xsl"
		    echo '</template>' >> "$temp_directory/pubdate.xsl"
		    echo '</stylesheet>' >> "$temp_directory/pubdate.xsl"
		    clear
		    for LD in `cat "$PODLIST"`;do
			LASTUPDATE=$("$PARSE_FEED" "$temp_directory/pubdate.xsl" "$LD" | awk -F '      ' '{print $2}' | head -n 1 2>/dev/null)
			echo ""
			printf "%-60s %s\n" "$LD" "$LASTUPDATE"
		    done
		    clean_up
		    exit 0
		    ;;
		* )
		    clean_up
		    exit 1
		    ;;
	    esac
	    done
	    clean_up
	    exit 0
	    ;;
	c)
		echo -n "Are you sure you want to clean your download directory ? (y/n) "
		read CLEAN_CHOISE
		if [ "CLEAN_CHOISE" == "y" ];then
		    rm "$download_directory"/* 2>/dev/null
		    rm "$temp_directory"/* 2>/dev/null
		    echo -e "\033[0;31mDirectory Cleaned\033[0m"
		    else
			exit 0
		fi
		exit 0
		;;
	a)
		if [ ! -d "$archive_directory" ];then
		    echo -e "\033[0;32mMaking archive directory\033[0m"
		    echo ""
		    mkdir "$archive_directory"
		fi
		# Remove Bittorent files
		for br in `ls "$download_directory"`
		do
		    Bittrm=$(file -b "$download_directory"/"$br" | awk '{print $1}')
		    if [ "$Bittrm" == "BitTorrent" ];then
			rm "$download_directory"/"$br"
		    fi
		done
		rm "$download_directory"/latest.m3u 2>/dev/null
		mv -v "$download_directory"/* "$archive_directory" 2>/dev/null
		rm "$lock" 2>/dev/null
		echo -e "\033[0;31mPodcasts archived\033[0m"
		exit 0
		;;
	p)
		$multimedia_player "$download_directory/latest.m3u" &
		rm "$lock" 2>/dev/null
		exit 0
		;;
	d)
		download="y"
		;;
	l)
		Download_limit="--limit-rate=$OPTARG""k"
		;;
	f)
		full="y"
		;;
	h)
		Usage
		rm "$lock" 2>/dev/null
		exit 0
		;;
	?)
		echo "Unexpected option \"$OPTARG\""
		echo ""
		Usage
		;;
   esac

done

shift $(($OPTIND - 1))

#<--------------------------------------------------->
}

CREATING_DIR ()
{
#####################################################
# Creating directories
#####################################################

mkdir -p "$main_directory"
mkdir -p "$temp_directory"
mkdir -p "$download_directory"
touch "$history"

#<--------------------------------------------------->
}

UPDATE () {

#####################################################
# Downloading feeds
#####################################################

echo "#################################"
echo "# Downloading feeds"
echo "#################################"
echo ""

if [[ ! -f "$PODLIST" || ! -s "$PODLIST" ]]
then
    touch "$PODLIST"
    echo -e "\033[0;31mFile "$PODLIST" is empty\033[0m"
    echo ""
    exit 1
fi

echo ""

Total=$(cat -n "$PODLIST" | awk '{print $1}' | tail -n 1)

for i in `cat "$PODLIST"`
do
Current=$(ls "$temp_directory" | wc -l)
Sub=$(($Current*100))
Percent=$(($Sub/$Total))

clear

echo "#################################"
echo "# Downloading feeds"
echo "#################################"
echo ""
echo ""
echo -e -n "\033[0;32m $Percent%\033[0m" 
Progressbar $Percent
echo ""
echo ""
wget -t 1 -T 30 -P "$temp_directory" "$i"
done

#<--------------------------------------------------->

#####################################################
# Filter the feeds from the enclosure
#####################################################

if [ ! -f "$main_directory/parse_enclosure.xsl" ]
then
	echo ""
	echo '<?xml version="1.0"?>
	<stylesheet version="1.0"
		xmlns="http://www.w3.org/1999/XSL/Transform">
		<output method="text"/>
		<template match="/">
		<apply-templates select="/rss/channel/item/enclosure"/>
		</template>
		<template match="enclosure">
		<value-of select="@url"/><text>&#10;</text>
	</template>
	</stylesheet>' > "$main_directory/parse_enclosure.xsl"
fi

if [ ! -f "$main_directory/parse_all.xsl" ]
then
	echo ""
	echo '<?xml version="1.0"?>
	<stylesheet version="1.0"
		xmlns="http://www.w3.org/1999/XSL/Transform">
		<output method="text"/>
		<template match="/">
		<apply-templates select="/rss/channel/item"/>
		</template>
		<template match="item">
		<value-of select="title"/><text>&#10;</text>
		<value-of select="enclosure/@url"/><text>&#10;</text>
	</template>
	</stylesheet>' > "$main_directory/parse_all.xsl"
fi

if [ ! -f "$main_directory/parse_link.xsl" ]
then
	echo ""
	echo '<?xml version="1.0"?>              
        <stylesheet version="1.0"                
                xmlns="http://www.w3.org/1999/XSL/Transform">
                <output method="text"/>                      
                <template match="/">                         
                <apply-templates select="/rss/channel/item"/>
                </template>                                            
                <template match="item">                           
                <value-of select="link"/><text>&#10;</text>            
        </template>                                                    
        </stylesheet>' > "$main_directory/parse_link.xsl"
fi

if [ ! -f "$main_directory/parse_all_link.xsl" ]
then
	echo ""
	echo '<?xml version="1.0"?>
        <stylesheet version="1.0"
                xmlns="http://www.w3.org/1999/XSL/Transform">
                <output method="text"/>
                <template match="/">
                <apply-templates select="/rss/channel/item"/>
                </template>
                <template match="item">
                <value-of select="title"/><text>&#10;</text>
                <value-of select="link"/><text>&#10;</text>
        </template>
        </stylesheet>' > "$main_directory/parse_all_link.xsl"
fi

cd "$temp_directory"

echo ""
echo "Please wait... Parsing the feeds"
echo ""

for p in `ls`
do
	$PARSE_FEED "$main_directory/parse_enclosure.xsl" $p >> $p.log 2>/dev/null
	if [ -s "$p.log" ];then
	    $PARSE_FEED "$main_directory/parse_all.xsl" $p >> title.txt 2>/dev/null
	else
	    # if feed doesnt contain enclosure tag it will use the link tag instead
	    $PARSE_FEED "$main_directory/parse_link.xsl" $p >> $p.log 2>/dev/null
	    $PARSE_FEED "$main_directory/parse_all_link.xsl" $p >> title.txt 2>/dev/null
	fi
	
done

#<--------------------------------------------------->

#####################################################
# Clean the output of the filter
#####################################################

head -n $podcast_number *.log | sed -e '/\=\=/d' -e '/^$/d' >> final.txt

#<--------------------------------------------------->

clear
}

DOWNLOAD () {

#####################################################
# Download the podcast and keep a history of it
#####################################################

echo "#################################"
echo "# Download or stream the podcast"
echo "#################################"
echo ""

echo "Options:"
echo "--------"
echo ""
echo "Press Ctrl+c to quit at any time"
echo ""
echo "! Resume is supported !"
echo ""
echo "d = Download , s = Stream , c = Catalogue , n = Skip"
echo ""
echo ""

echo "New shows:"
echo "----------"
echo ""

NEW_SHOWS=0

for t in `cat final.txt`
do
  clean=$(basename "$t")
  same_name=$(grep -c "$clean" final.txt)
  
  # checks to see if the podcast name doesnt change
  if [ $same_name -gt 1 ];then
	test=$(grep -c -F "$t" "$history") 2>/dev/null
  else
	test=$(grep -c -F "$clean" "$history") 2>/dev/null
  fi
  
  if [ $test -eq 0 ];then
	TITLE=$(grep -F -B 1 -m 1 "$clean" title.txt)
	echo "$TITLE"
	echo ""
   	NEW_SHOWS=$((NEW_SHOWS+1))
  fi
done

echo ""
echo "( $NEW_SHOWS new shows )"
echo ""

echo ""
echo "Actions:"
echo "--------"
echo ""

for d in `cat final.txt`
do
    clean_title=$(basename "$d")
    same_nameA=$(grep -c "$clean_title" final.txt)
  
    # checks to see if the podcast name doesnt change
    if [ $same_nameA -gt 1 ];then
	temp=$(grep -c -F "$d" "$history") 2>/dev/null
    else
	temp=$(grep -c -F "$clean_title" "$history") 2>/dev/null
    fi
    
    if [ $temp -eq 0 ];then
	if [ "$download" == "y" ];then
           choise="d"
	elif [ "$full" == "y" ];then
	    echo "$d" >> "$history"
	    echo ""
	    echo "$clean_title has been added"
	continue
	else
	# you can prioritize the downloads by adding a number after d : d1, d2, d3,....
	    read -p "Download , Stream or catalogue : $clean_title (d/s/c/n) ? " choise
	    echo "$choise*$d" >> choises.txt 2>/dev/null
	fi
	
	echo ""
	
    fi
done

sort choises.txt -o choises-sorted.txt 2>/dev/null

# Adds the date to the history file
HISTORYADD=$(grep -c '^d\|^c' choises.txt 2>/dev/null)

if [ $HISTORYADD -ne 0 2>/dev/null ];then
	echo "$DATESTR" >> "$history"
fi

DOWNLOAD_SHOWS_NUM=1

for d in `cat choises-sorted.txt 2>/dev/null`
do

	Option=$(echo "$d" | cut -c 1)
	Filepath=$(echo "$d" | awk -F* '{print $2}')
	clean_tag=$(basename "$d")
	DOWNLOAD_SHOWS_TOTAL=$(cat choises-sorted.txt | cut -c 1 | grep d | wc -l)
	
	### Downloading ###

	if [ "$Option" == "d" ] || [[ "$Option" == "d[0-9]*" ]] || [ "$Option" == "D" ] || [ "$Option" == "y" ];then
	    echo ""
	    echo -e "\033[0;32mDownloading ($DOWNLOAD_SHOWS_NUM/$DOWNLOAD_SHOWS_TOTAL) : \033[0m" "$clean_tag"
	    echo ""
	
		wget -c $Download_limit -O "$download_directory/$clean_tag" "$Filepath" && echo "$Filepath" >> "$history"
	    
	    # This line for converting the %5B and %5D from the filename and removing question marks at end
	    clean_tag_bit=$(echo "$clean_tag" | sed -e s/%5B/[/ | sed -e s/%5D/]/ | sed -e s/%28/\(/ | sed -e s/%29/\)/ | sed -e 's/?.*$//')
	    
	    mv "$download_directory/$clean_tag" "$download_directory/$clean_tag_bit" 2>/dev/null
	    
	    ### Check if its a torrent ###
	    
	    Bitt=$(file -b "$download_directory/$clean_tag_bit" | awk '{print $1}')
	    if [ "$Bitt" == "BitTorrent" ];then
		nohup "$bittorrent_client" "$download_directory/$clean_tag_bit" &
		sleep 3
		echo ""
		read -p "Delete torrent file ? (y/n) " del_torr
		echo ""

		if [ "$del_torr" == "y" ] || [ "$del_torr" == "Y" ];then
			rm "$download_directory/$clean_tag_bit"
		fi

	    fi

	DOWNLOAD_SHOWS_NUM=$((DOWNLOAD_SHOWS_NUM+1))

	### Streaming ###

	elif [ "$Option" == "s" ] || [ "$Option" == "S" ];then
	    echo ""
	    echo -e "\033[0;32mStreaming : \033[0m" "$clean_tag"
	    echo ""
	    echo "$Filepath" >> "$history"
	    $stream_player "$Filepath" &

	### Catalogue ###

	elif [ "$Option" == "c" ];then
	    echo ""
	    echo "Added $clean_tag"
	    echo ""
	    echo "$Filepath" >> "$history"
	
	### Skipping ###

	else
	    echo ""
	    echo -e "\033[0;31mSkipping : \033[0m" "$clean_tag"
	    echo ""
	fi
done

#<--------------------------------------------------->

#####################################################
# Create an m3u playlist
#####################################################

ls -1rc "$download_directory" | grep -v m3u > "$download_directory/latest.m3u"

#<--------------------------------------------------->

}

CLEANUP () {

#####################################################
# Cleanup
#####################################################

rm "$lock"
rm "$main_directory"/temp/* 2>/dev/null

}

DEPENDENCY_CHECK
OPTIONS "$@"	# @ is used to pass the arguments to the function
CREATING_DIR
UPDATE
DOWNLOAD
CLEANUP

echo "#################################"
echo -e "#""\033[0;32m Done \033[0m"
echo "#################################"
echo ""
