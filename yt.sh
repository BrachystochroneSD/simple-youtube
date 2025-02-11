#!/bin/sh

CONFIG=/etc/yt.conf
HOME_CONFIG=${HOME}/.config/yt.conf
APPNAME=simple-youtube

if [ -f "$HOME_CONFIG" ]; then
    . "$HOME_CONFIG"
else
    . "$CONFIG"
fi

CACHE=${HOME}/.cache/simple-youtube
mkdir -p $CACHE

[ -z "$MAX_RESULTS" ] && MAX_RESULTS=35
[ -z "$RSSFILE" ] && RSSFILE="${HOME}/.emacs.d/elfeed.org"
[ -z "$COLS" ] && COLS=250

[ -z "$YOUTUBE_APIKEY" ] && echo "Need to configure api key in $CONFIG" && exit 1

HISTORY_FILE="${CACHE}/searchhistory"
LAST_VIDEO_FILE="${CACHE}/last_video"

touch "$LAST_VIDEO_FILE"
touch "$HISTORY_FILE"

[ -z "$MENU_CMD" ] && MENU_CMD="dmenu"

error_print () {
    echo "Error: $1"
    notify-send -a "$APPNAME" -i youtube -e "Error: $1"
    exit 1
}

html_to_ascii () {
    # sed 's/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&quot;/\"/g; s/#&#39;/\'"'"'/g; s/&ldquo;/\"/g; s/&rdquo;/\"/g;'
    cat | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g; s/&\#39;/'"'"'/g'
}

check_internet_connection () {
    ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 || error_print "No internet connection"
}

launch_youtube_link() {
    local yt_link="$1" _sample_rate= _res=
    echo "$yt_link" | xclip -selection clipboard # clipboard to share with your friend !

    res=$(printf "1080\n720\n360\nno-video" | $MENU_CMD -i -p "Which resolution? (if avalaible)") || get_search_query
    if [ $res = "no-video" ];then
        chan=$(printf "stereo\nmono" | $MENU_CMD -i -p "Channels") || get_search_query
        [ "$chan" = "mono" ] && chan="--audio-channels=1" || chan=""
        _sample_rate=$(printf "max\n441000\n38000" | $MENU_CMD -i -p "Channels") || get_search_query
        echo "$_sample_rate" | grep -q "^[0-9][0-9]*$" && _sample_rate="--audio-samplerate=$_sample_rate" || _sample_rate=""
        exec st -e mpv --no-video "$chan" "$_sample_rate" "$yt_link" || $NOTIFY_CMD  "MPV ERROR " "Can't launch mpv"
    else
        echo $yt_link > $LAST_VIDEO_FILE
        mpv --ytdl-format="bestvideo[height<=?$res]+bestaudio/best" "$yt_link" || $NOTIFY_CMD  "MPV ERROR " "Can't launch the video"
    fi
    exit
}

get_channel_infos () {
    channel_name=$(grep "youtube.com" "$RSSFILE" | sed 's/\*\*\* \[\[.*\]\[//' | sed 's/\]\]//' | $MENU_CMD -l 10 -i -p "Channel Search") || get_search_query
    channelsearch=$(curl -s \
                         -G https://www.googleapis.com/youtube/v3/search \
                         --data-urlencode "q=$channel_name" \
                         -d "type=channel" \
                         -d "maxResults=25" \
                         -d "part=snippet" \
                         -d "key=$YOUTUBE_APIKEY")

    chanchoice=$(echo "$channelsearch" | jq -r ".items[] | .snippet.channelTitle, .snippet.description" | awk '(NR%2==1){chantitle=$0}(NR%2==0){printf ("%2d: %s : %s\n",NR/2,chantitle,$0)}' | $MENU_CMD -l 25 -i -p "Which channel ?") || get_search_query
    local channum=$(echo "$chanchoice" | sed 's/:.*/-1/' | bc)

    local channame=${chanchoice#*: }
    channame=${channame%% :*}
    channel_id=$(echo "$channelsearch" | jq -r ".items[$channum].snippet.channelId")

    # Ask for saving the channel and save it on rss.org file
    ! grep -q "$channel_id" "$RSSFILE" && local save_or_not=$(printf "No\nYes" | $MENU_CMD -i -p "Save this channel ?")
    [ "$save_or_not" = "Yes" ] && printf "*** [[https://www.youtube.com/feeds/videos.xml?channel_id=%s][%s]]\n" "$channel_id" "$channame" >> "$RSSFILE"
}

get_search_query () {
    channel_id="" # reset channel_id
    local menu_entry=$(head -n 1 "$HISTORY_FILE" | awk '{print$0}END{printf "\nChannel Search\nOrder\nShow History\nClear History"}' | $MENU_CMD -i -l 20 -p "Youtube search:")
    [ -z "$menu_entry" ] && exit 1

    case "$menu_entry" in
        http*) launch_youtube_link "$menu_entry" ;;
        "Channel Search") get_channel_infos; search_query=$(echo | $MENU_CMD -i -l 20 -p "Search on this channel:") || get_search_query ;;
        "Order") sort=$(echo -e "relevance\ndate\nrating\ntitle\nviewCount" | $MENU_CMD -i -l 20 -p "Sort by: "); get_search_query ;;
        "Show History") search_query=$($MENU_CMD -i -l 20 -p "Search in History:" < "$HISTORY_FILE" ) || get_search_query ;;
        "Clear History") printf "" > "$HISTORY_FILE"; get_search_query ;;
        *)
            search_query="$menu_entry"
            ! grep -q "^$search_query$" "$HISTORY_FILE" && { echo "$search_query"; cat "$HISTORY_FILE"; } > /tmp/youthistotmp && mv /tmp/youthistotmp "$HISTORY_FILE"
            printf "Searching for %s\n" "$search_query"
    esac
    mpv_launch
}

mpv_launch() {
    local yt_fetch=
    [ -z "$sort" ] && sort="relevance" # take default

    if [ -z "$channel_id" ]; then
        yt_fetch=$(curl -s \
                        -G https://www.googleapis.com/youtube/v3/search \
                        -d "type=video,playlist" \
                        -d "maxResults=$MAX_RESULTS" \
                        -d "key=$YOUTUBE_APIKEY" \
                        -d "part=snippet" \
                        -d "order=$sort" \
                        -d "relevanceLanguage=en" \
                        -d "relevanceLanguage=fr" \
                        --data-urlencode "q=$search_query"
                )
    else
        yt_fetch=$(curl -s \
                        -G https://www.googleapis.com/youtube/v3/search \
                        -d "type=video,playlist" \
                        -d "maxResults=$MAX_RESULTS" \
                        -d "key=$YOUTUBE_APIKEY" \
                        -d "part=snippet" \
                        -d "order=$sort" \
                        -d "relevanceLanguage=en" \
                        -d "relevanceLanguage=fr" \
                        -d "channelId=$channel_id" \
                        --data-urlencode "q=$search_query"
                )
    fi
    echo "$yt_fetch"
    testcold=$(echo "$COLS" / 2.2 | bc)
    choicenum=$(echo "$yt_fetch" | jq -r ".items[] | .id.kind,.snippet.title, .snippet.channelTitle, .snippet.publishedAt" | html_to_ascii | awk -v cols="$testcold" '(NR%4==1){if($0=="youtube#playlist"){play="Playlist : "}else{play=""}}(NR%4==2){name=$0}(NR%4==3){chan=$0}(NR%4==0){printf ("%2d: %-" cols "s %-15s %.10s \n", NR/4, substr(play name,0,cols), substr(chan,0,15), $0)}' | sed 's/|//g' | $MENU_CMD -l 30 -i | sed 's/:.*/ - 1/' | bc )

    [ -z "$choicenum" ] && get_search_query

    choicekind=$(echo "$yt_fetch" | jq -r ".items[$choicenum].id")
    if [ "$( echo "$choicekind" | jq -r ".kind" )" = "youtube#video" ]; then
        launch_youtube_link "https://www.youtube.com/watch?v=$(echo "$choicekind" | jq -r ".videoId")"
    else
        launch_youtube_link "https://www.youtube.com/playlist?list=$(echo "$choicekind" | jq -r ".playlistId")"
    fi
}

check_internet_connection
if [ -n "$1" ]; then
    launch_youtube_link "$1"
else
    get_search_query
fi
