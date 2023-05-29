#!/usr/bin/bash

# FUNCTION : print help 
printHelp(){
    echo "MAKE SURE NeteasseCloudMusicApi IS SET"
    echo "NeteaseCloudMusicApi:  https://github.com/Binaryify/NeteaseCloudMusicApi"
    echo "jq: https://github.com/stedolan/jq"
    echo -e "\nUsage: $0 -s songId"
    echo -e "Usage: $0 -p playlistId"
    echo "Short options:        long options:"
    echo -e "\t-a\t\t--albumId\t albumId1,albumId2,...)"
    echo -e "\t-c\t\t--cookie\tusing a cookie file"
    echo -e "\t-h\t\t--help"
    echo -e "\t-n\t\t--numerical\tname numerically"
    echo -e "\t-p\t\t--playlistId"
    echo -e "\t-s\t\t--songId songId1,songId2,..."
    echo -e "\t-t\t\t--usingTitle\tname file with title"
    echo -e "\tname files with title may cause errors due to illegal characters in your file system"
    echo -e "\t-P\t\t--dlPath be careful with ~/ for ~ expand inside double quotes"
    echo -e "\t\t\t--acc\n\t\t\t--pw"
    
}

IFS_OLD=$IFS

# init 
dlPath=$( pwd )
dlVIP=1
usingTitle=0
count=1

# h psa Pc acc pw vnt
ARGS=$( getopt -o hntva:c:p:s:P: --long acc:,pw: -- "$@" )
eval set -- "${ARGS}"

# ARGS 
while true 
do
    case "$1" in
        -h|--help)
            printHelp
            shift;;
        -p|--playlistId)
            playlistId=$2
            shift 2;;
        -s|--songId)
            songId=$2
            shift 2;;
        -a|--album)
            albumId=$2
            shift 2;;
        -P|--dlPath)
            dlPath=$2
            #        coco↓ space    
            tmp=${dlPath: -1}
            if [ "$tmp" == "/" ]
            then
	            dlPath=${dlPath:0:-1}
            fi
            shift 2;;
        -c|--cookie)
            cookieFile=$2
            cookieNo=0
            shift 2;;
        --acc)
            account=$2
            shift 2;;
        --pw)
            password=$2
            shift 2;;
        -v|--dlVIP)
            dlVIP=1
            shift ;;
        -n|--numerical)
            usingTitle=0
            shift ;;
        -t|--usingTitle)
            usingTitle=1
            shift ;;
        --)
            shift
            break;;
        *)
            echo "ERROR: unknown para."
            exit 1;;
    esac
done

# mkdir $dlpath
if [ ! -e $dlPath ]
then
    mkdir $dlPath
fi

# FUNCTION : string validation 
# KEY VARIABLE: $stringF
# invalid chars : \/:*?"<>|
stringF=
jug="first"
stringValidation(){

    # "" -> 「」
    jug="first"
    while [ $( echo "$stringF" | grep '"' ) ]
    do
	    if [ "$jug" == "first" ]
	    then
	    	stringF=$( printf %s "$stringF" | sed -z 's/\"/「/' )
	    	jug="last"
	    else
		    stringF=$( printf %s "$stringF" | sed -z 's/\(.*\)"/\1」/' )
		    jug="first"
	    fi
    done

    # [ ] bad wget
    jug="first"
    
    fff=` echo "$stringF" | grep -E "\[|\]" `
    if [ "$fff" ]
    then
        fff=1
    else
        fff=0
    fi
    while [ $fff ]
    do
	    if [ "$jug" == "first" ]
	    then
	    	stringF=$( printf %s "$stringF" | sed -z 's/\[/「/' )
	    	jug="last"
	    else
		    stringF=$( printf %s "$stringF" | sed -z 's/\(.*\)]/\1」/' )
		    jug="first"
	    fi


        fff=` echo "$stringF" | grep -E "\[|\]" `
        if [ "$fff" ]
        then
            fff=1
        else
            break
        fi
    done

    # ?  -> ？
    # \/ -> ／
    # <> -> 〈〉　＜＞
    # *  ->  ⁑
    # :  -> ：
    # |  -> ❙              
    # temporary
    stringF=$( echo "$stringF" | sed 's/?/？/g;s/\\/／/g;s/\//／/g;s/</〈/g;s/>/〉/g;s/*/⁑/g;s/:/：/g;s/|/❙/g' )

    # ' is legal in file system 
    # BUT WGET DISLIKE IT
    # SO
    stringF=$( echo "$stringF" | sed "s/'/’/g" )
    # ./ in file path
    stringF=$( echo "$stringF" | sed 's/.\//．\//g' )
    while [ "${stringF: -1}" == "." ]
    do
        stringF=${stringF:0:-1}
        stringF="${stringF}．"
    done
    # then we get a valid file name 
}

# FUNTCION: get playlist Info 
# KEY VARIABLE: $playlistIdF $playlistInfo $playlistName $playlistCoverUrl 
getPlaylistInfo(){
    playlistInfoLink="http://localhost:3000/playlist/detail?id=$playlistIdF"
    playlistInfo=$( wget $playlistInfoLink -qO - )
    playlistName=$( echo $playlistInfo | jq '.playlist.name' )
    playlistCoverUrl=$( echo $playlistInfo | jq '.playlist.coverImgUrl' )

    playlistSongIds=$( echo $playlistInfo | jq '.playlist.trackIds[] | .id' )

}

# FUNCTION: get album info
# KEY VARIABLE: $albumIdF $albumInfo $albumName $albumCoverUrl $albumNameAlias $albumSongIds
getAlbumInfo(){
    albumInfoLink="http://localhost:3000/album?id=$albumIdF"
    albumInfo=$( wget $albumInfoLink -qO - )
    albumName=$( echo $albumInfo | jq '.album.name' )
    albumName=${albumName:1:-1}
    albumNameAlias=$( echo $albumInfo | jq '.album.alias' )
    albumCoverUrl=$( echo $albumInfo | jq ".album.picUrl" )
    albumDesc=$( echo $albumInfo | jq ".album.description" )
    albumBriefDesc=$( echo $albumInfo | jq ".album.briefDesc" )
    albumSongIds=$( echo $albumInfo | jq '.songs[]|.id' )
    albumSongTitles=$( echo $albumInfo | jq '.songs[]|.name' )

    songTotal=$( echo $albumInfo | jq '.songs|length' )
    # addition 
    # seems artistAlias only appears in album info ?
    # DEPRECATED 
    # artistAlias=$( echo $albumInfo | jq ".songs[].ar[].alia)
}

# FUNCTION: creat cookie file
# to renew cookie file, delete it  
creatCookie(){

    if [ -e "$dlPath/cookie.txt" ]    
    then
        cookieNo=0
    else
        cookieNo=1
    fi

    if [ $account ] && [ $password ] && [ $cookieNo ]
    then
        curl -d "phone=$account&password=$password" -c "$dlPath/cookie.txt" http://localhost:3000/login/cellphone
        echo "Cookie created, CookieFile is $dlPath/cookie.txt"
    fi
    cookieFile="$dlPath/cookie.txt"
    read x
}


# download path playlist/album 
dlPathPA=
# download path single song 
dlPathSS=
# downlaod path current, can be dlPath(pwd) or dlPathPlaylist/dlPathAlbum
dlPathCU=
# resource name 
resName=

# FUNTCION: get playlist Info 
# KEY VARIABLE: $playlistIdF $playlistInfo $playlistName $playlistCoverUrl 
getPlaylistInfo(){
    playlistInfoLink="http://localhost:3000/playlist/detail?id=$playlistIdF"
    playlistInfo=$( wget $playlistInfoLink -qO - )
    playlistName=$( echo $playlistInfo | jq '.playlist.name' )
    playlistCoverUrl=$( echo $playlistInfo | jq '.playlist.coverImgUrl' )

    playlistSongIds=$( echo $playlistInfo | jq '.playlist.trackIds[] | .id' )

}

# FUNCTION: get album info
# KEY VARIABLE: $albumIdF $albumInfo $albumName $albumCoverUrl $albumNameAlias $albumSongIds
getAlbumInfo(){
    albumInfoLink="http://localhost:3000/album?id=$albumIdF"
    albumInfo=$( wget $albumInfoLink -qO - )
    albumName=$( echo $albumInfo | jq '.album.name' )
    albumName=${albumName:1:-1}
    albumNameAlias=$( echo $albumInfo | jq '.album.alias' )
    albumCoverUrl=$( echo $albumInfo | jq ".album.picUrl" )
    albumDesc=$( echo $albumInfo | jq ".album.description" )
    albumBriefDesc=$( echo $albumInfo | jq ".album.briefDesc" )
    albumSongIds=$( echo $albumInfo | jq '.songs[]|.id' )
    albumSongTitles=$( echo $albumInfo | jq '.songs[]|.name' )

    songTotal=$( echo $albumInfo | jq '.songs|length' )
    # addition 
    # seems artistAlias only appears in album info ?
    # DEPRECATED 
    # artistAlias=$( echo $albumInfo | jq ".songs[].ar[].alia)
}

# FUNCTION: creat cookie file
# to renew cookie file, delete it  
creatCookie(){

    if [ -e "$dlPath/cookie.txt" ]    
    then
        cookieNo=0
        echo have cookie 
    else
        cookieNo=1
        echo have no cookie
    fi

    if [ $account ] && [ $password ] && [ $cookieNo ]
    then
        curl -d "phone=$account&password=$password" -c "$dlPath/cookie.txt" http://localhost:3000/login/cellphone
        echo "Cookie created, CookieFile is $dlPath/cookie.txt"
    fi
    cookieFile="$dlPath/cookie.txt"
}


# download path playlist/album 
dlPathPA=
# download path single song 
dlPathSS=
# downlaod path current, can be dlPath(pwd) or dlPathPlaylist/dlPathAlbum
dlPathCU=
# resource name 
resName=

# FUNCTION
# KEY VARIABLE: $songInfo 
dlSong() {

    songInfo=$( wget http://localhost:3000/song/detail?ids=$songIdF -qO - )
    title=$( echo $songInfo | jq '.songs[]|.name' )
    album=$( echo $songInfo | jq '.songs[]|.al.name' )
    titleTransl=$( echo $songInfo | jq '.songs[]|.tns' )
    isVIP=$( echo $songInfo | jq '.songs[]|.fee' )
    artists=$( echo $songInfo | jq '.songs[]|.ar[]|.name' | sed 's/\"//g' )
    artist=
    for i in $artists
    do
        artist="${artist}&${i}"
    done

    artist=${artist/&/}
    stringF=$artist
    stringValidation
    artistV=$stringF

    title=${title:1:-1}
    stringF=$title
    stringValidation
    titleV=$stringF

    album=${album:1:-1}
    stringF=$album
    stringValidation
    albumV=$stringF


    if [ $usingTitle ]
    then
        dlPathSS="${titleV}_${artistV}"
    else
        dlPathSS=$( printf "03%d" $count )
    fi

    cd "$dlPathCU"

    if [ -e "$dlPathSS" ]
    then
        dlPathSS="${dlPathSS}_foo"
    fi

    mkdir "$dlPathSS"
    resName=$titleV

    # album pics
    alPicUrl=$( echo $songInfo | jq '.songs[]|.al.picUrl' )
    alPicUrl=${alPicUrl:1:-1}
    alPicExt=${alPicUrl##*.}


#   if [ 1 ]
#    then
#        audioUrlInfo=$( wget --header="Cookie:MUSIC_U=$VALUE; __csrf=$VALUE; NMTID=$VALUE"  "http://localhost:3000/song/url/v1?id=$songIdF&level=lossless" -qO - )
#        echo "using a cookie file "
#    else 
#        audioUrlInfo=$( wget http://localhost:3000/song/url?id=$songIdF -qO - )
#    fi

    audioUrlInfo=$(wget "http://localhost:3000/song/url/v1?id=${songIdF}&level=lossless" -qO - )
	audioUrl=$( echo $audioUrlInfo | jq '.data[]|.url' )
    
    audioUrl=${audioUrl:1:-1}
    audioExt=${audioUrl##*.} 

    audioFile="$resName.$audioExt"
  
	# ckpti
	echo -e "\nckpt:"
	echo "title is $title"
    echo "artist is $artist"
	echo "album is $album"
	echo -e "audioFile name is $audioFile \n"

    # audio file download 
    if [ $dlVIP ] || [ !$isVIP ]
    then
        wget -qO "$dlPathCU/$dlPathSS/$audioFile" $audioUrl
    fi
    alPic="AlbumPic.$alPicExt"
    wget -qO "$dlPathCU/$dlPathSS/$alPic" $alPicUrl
    

    # lyrics 
    lrcInfo=$( wget http://localhost:3000/lyric?id=$songIdF -qO - )
    # ja
	lrc=$( echo $lrcInfo | jq '.lrc.lyric' )
	lrc=${lrc:1:-1}
    echo $lrc >| "$dlPathCU/$dlPathSS/${resName}_jp.lrc"
	sed -i 's/\\n/\n/g' "$dlPathCU/$dlPathSS/${resName}_jp.lrc"
    # cn
	tlrc=$( echo $lrcInfo | jq '.tlyric.lyric' )
    tlrc=${tlrc:1:-1}
	echo $tlrc >| "$dlPathCU/$dlPathSS/${resName}_zh.lrc"
	sed -i 's/\\n/\n/g' "$dlPathCU/$dlPathSS/${resName}_zh.lrc"
    # romaji
	rmlrc=$( echo $lrcInfo | jq '.romalrc.lyric' )
    rmlrc=${rmlrc:1:-1} 
	echo $rmlrc >| "$dlPathCU/$dlPathSS/${resName}_roma.lrc"
	sed -i 's/\\n/\n/g' "$dlPathCU/$dlPathSS/${resName}_roma.lrc"

    # combine 
    paste "$dlPathCU/$dlPathSS/${resName}_jp.lrc" "$dlPathCU/$dlPathSS/${resName}_zh.lrc" |tr "\t" "\n" > "$dlPathCU/$dlPathSS/$resName.lrc"

    # adding info
	echo "Title: $title" >| "$dlPathCU/$dlPathSS/info.txt"
    echo "TitleTranslated: $titleTransl" >> "$dlPathCU/$dlPathSS/info.txt"
    echo "artist: $artist" >> "$dlPathCU/$dlPathSS/info.txt"
    echo "album: $album" >> "$dlPathCU/$dlPathSS/info.txt"
    # albun alias ?

    # tageditor
    cd "$dlPathCU/$dlPathSS"
    coverImg="AlbumPic.$alPicExt"
    tageditor set title="$title" album="$album" artist="$artist" cover="${coverImg}":front-cover --files="${audioFile}"
   	rm -f "$dlPathCU/$dlPathSS/$audioFile.bak"

    # csv file 
    if [ !$songId ]
	then
        if [ $count -eq 1 ]
        then
            printf '\xEF\xBB\xBF' >| "$dlPathCU/Details.csv"
            echo "No,Title,Artist,Album,NeteaseMusicId,IsVIP?" >> "$dlPathCU/Details.csv"
        fi

        ttt=$( echo $songIdF )
        echo "$count,$title,$artist,$album,$ttt,$isVIP" | sed 's/^M//g' >> "$dlPathCU/Details.csv"
	fi


}

# multi-playlist/album download support

dlPathCU=$dlPath

# if [ ! "$cookieFile" ]
# then
#     creatCookie
# fi
# echo using cookie $cookieFile

if [ "$songId" ]
then
    songId=${songId//,/ }
    for sId in $songId
    do
        songIdF=$sId
        dlSong
    done
fi


if [ "$albumId" ]
then 

    albumId=${albumId//,/ }
    for aId in $albumId
    do

        albumIdF=$aId
        getAlbumInfo

        stringF=$albumName
        stringValidation
        albumNameF=$stringF

        dlPathCU="$dlPath/$albumNameF"
        if [ -e "$dlPathCU" ]
        then
            dlPathCU="${dlPathCU}_foo"
        fi
        mkdir "$dlPathCU"

        count=1
        for sId in $albumSongIds
        do 
            songIdF=$sId
            dlSong
            count=$(($count+1))
        done

# KEY VARIABLE: $albumIdF $albumInfo $albumName $albumCoverUrl $albumNameAlias $albumSongIds
        # album infos
        echo "Album: $albumName" >| "$dlPathCU/AlbumDetails.txt"
        echo "Alias: $albumNameAlias" >> "$dlPathCU/AlbumDetails.txt"
        echo -e "Brief Description: $albumBriefDesc" >> "$dlPathCU/AlbumDetails.txt"
        echo -e "Full Description: $albumDesc" >> "$dlPathCU/AlbumDetails.txt"
        echo "" >> "$dlPathCU/AlbumDetails.txt"

        albumCoverUrl=${albumCoverUrl:1:-1}
        alCoverExt=${albumCoverUrl##*.}

        AlbumCover="AlbumCover.$alCoverExt"
       
        wget -qO "$dlPathCU/$AlbumCover" $albumCoverUrl

        for(( i=0;i<$songTotal;i++ ))
        do
            info1=$( echo $albumInfo | jq .songs[$i].name )
            info1=${info1:1:-1}
            echo -e "$info1:  " | tr -d "\n"  >> "$dlPathCU/AlbumDetails.txt"
            
            artists=$( echo $albumInfo | jq .songs[$i] | jq '.ar[].name' | sed 's/\"//g' )
            for ar in $artists
            do
                echo "$ar " | tr -d "\n" >>  "$dlPathCU/AlbumDetails.txt"
            done
            echo "" >> "$dlPathCU/AlbumDetails.txt"
        done
        cp "$dlPathCU/Details.csv" "$dlPathCU/Details.csv.bak"
    done
fi

if [ "$playlistId" ]
then
    playlistId=${playlistId//,/ }
    for pId in $playlistId
    do
        playlistIdF=$pId
        getPlaylistInfo

# KEY VARIABLE: $playlistIdF $playlistInfo $playlistName $playlistCoverUrl 
        stringF=$playlistName
        stringValidation
        playlistNameF=$stringF

        dlPathCU="$dlPath/$playlistNameF"
        mkdir "$dlPathCU"

        count=1
        for sId in $playlistSongIds
        do 
            songIdF=$sId
            dlSong
            count=$(($count+1))
        done
    
        playlistCoverUrl=${playlistCoverUrl:1:-1}
        playlistCoverExt=${playlistCoverUrl##*.}

        playlistCover="PlaylistCover.$playlistCoverExt"
        wget -qO "$dlPathCU/$playlistCover" $playlistCoverUrl

        cp "$dlPathCU/Details.csv" "$dlPathCU/Details.csv.bak"
    done


fi 
