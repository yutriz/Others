# base on cloudmusic nodejs API
#
# Github:
# https://github.com/Binaryify/NeteaseCloudMusicApi
# Guide: 
# https://neteasecloudmusicapi.js.org/#/
# 
# Dec 7,2022 updated : 
# 	1. custom download path  
# 	2. SongTitle, artist, album ? --> No.x/songtitle.mp3 ...... leave the problem to music player, they'd sort the files
#   
#
#  IF AN ERROR OCCURRED, PLEASE DOWNLOAD MANUALLY


echo "usage: getPlaylist.sh [-p playlist_id] [-P path] [-v download_vip_songs(true/false)] [--acc] [--pw] [-c cookie]"
echo  -e "Mutli-playlist not supported yet\n\n"

scrpt_name=$0

# Transform long options to short option
for arg in "$@"; do
	shift
	case "$arg" in 
		'--help')
			set -- "$@" '-h'	;;
		'--pid')
			set -- "$@" '-p'	;;
		'--path')
			set -- "$@" '-P'	;;
		'--vip')
			set -- "$@" '-v'	;;
		'--cookie')
			set -- "$@" '-c'	;;
		'--acc')
			set -- "$@" '-A'	;;
		'--pw')
			set -- "$@" '-C'	;;
		*)
			set -- "$@" "$arg"	;;
	esac
done


# Default behavior
# will download part of vip song 
dl_VIP=true;

dl_path=`pwd`
win_sys=true;

OPTIND=1

while getopts 'c:v:p:A:C:P:h' opt; do
	case "$opt" in
		'p')
			playlistId=$OPTARG
			;;
		P)
			dl_path=$OPTARG	
			;;
		v)
			dl_VIP=$OPTARG
			;;
		A)
			account=$OPTARG
			;;
		C)
			pw=$OPTARG
			;;
		c)
			cookieFile=$OPTARG
			;;
		'h')
			echo usage
			;;
		'?')
			echo -e "Usage: \n $scrpt_name [-h] [-p] [-v] [-P] [--help] [--pid] [--path] [--vip]" 1>&2
			exit 1
			;;
	esac	
done

# remove options from positional parameters 
shift $(expr $OPTIND - 1)

last_c=${dl_path: -1}
if [ "$last_c" == "/" ]
then
	dl_path=${dl_path:0:-1}
fi

# ckpt
echo "pid is ${playlistId}"
echo -e "dl_path is $dl_path \n"
echo -e "acc is $account"
echo -e "pw is $pw"
echo -e "cookie is $cookieFile"


# get playlist information 
playlist_adr="http://localhost:3000/playlist/detail?id=$playlistId"
echo gaining info from $playlist_adr

# extract playlist info 
playlist_info=`wget $playlist_adr -qO -` 
playlist_name=`echo $playlist_info | jq '.playlist.name'`
playlist_coverImgUrl=`echo $playlist_info | jq '.playlist.coverImgUrl'`
playlist_coverImgUrl=${playlist_coverImgUrl:1:-1}
playlist_coverImgExt=${playlist_coverImgUrl##*.}

playlist_name=${playlist_name:1:-1}
jug="first"
while [ $(printf %s "$playlist_name" | grep '"') ]
do
	if [ "$jug" == "first" ]
	then
		playlist_name=$(printf %s "$playlist_name" | sed -z 's/\"/「/')
		jug="last"
	else
		playlist_name=$(printf %s "$playlist_name" | sed -z 's/\(.*\)"/\1「/')
		jug="first"
	fi
done

# hard to believe there are two different spaces 
# playlist_name=$( echo $playlist_name | sed 's/ /_/g;s/ /_/g' )

mkdir $dl_path
dir=${dl_path}/${playlist_name}


mkdir $dir

# create login cookie
if [ $account ] && [ $pw ] && [ ! $cookieFile ]
then
	curl -d "phone=$account&password=$pw" -c $dir/cookie.txt http://localhost:3000/login/cellphone
	cookieFile=${dir}/cookie.txt
	echo "using new created cookie file $cookieFile"
fi

#  only ${url:1:-1} works
wget -qO "${dir}/playlist_cover.${playlist_coverImgExt}"  ${playlist_coverImgUrl}


# write trackIds of the playlist 
SongIdFile=${dir}/playlist$playlistId
echo $playlist_info | jq '.playlist.trackIds[] | .id' > $SongIdFile


# counter 
total=`cat $SongIdFile | wc -l`
count=0


while read SongId
do
	count=$(($count+1))

	# songInfo=`curl 'http://localhost:3000/song/detail?ids='$SongId`
	songInfo=`wget http://localhost:3000/song/detail?ids=$SongId -qO -`


	ti=$(  echo $songInfo | jq '.songs[]|.name' )
	al=$(  echo $songInfo | jq '.songs[]|.al.name' )
	# tti = translated title
	tti=$( echo $songInfo | jq '.songs[]|.tns' )

	# 1 need a VIP
	# 0 free 
	IsVIP=$( echo $songInfo | jq '.songs[]|.fee' )


	ars=$( echo $songInfo | jq '.songs[]|.ar[]|.name' | sed 's/\"//g' )
    ar=
    for i in $ars
    do
        ar=${ar}\&${i}
    done

	# remove " in "title" 
    ar=${ar/\&/}
    ti=${ti:1:-1}
    al=${al:1:-1}

	ti_dir=$ti
	jug="first"	
	while [ $(printf %s "$ti_dir" | grep '"') ]
	do
	    if [ "$jug" == "first" ]
	    then
	        ti_dir=$(printf %s "$ti_dir" | sed -z 's/\"/「/')
	        jug="last"
	    else
	        ti_dir=$(printf %s "$ti_dir" | sed -z 's/\(.*\)"/\1「/')
			jug="first"
			fi
	done
	# older ver 
	# ti_dir=$( echo $ti | sed 's/\"/〝/g;s/\\?/？/g;s/\?/？/g;s/\\!/！/g;s/\!/！/g;s/\\:/：/g;s/\:/：/g;s/\\</＜/g;s/\\>/＞/g;s/\\-/_/g;s/(/（/g;s/)/）/g;s/=/＝/g;s/+/＋/g' )

	# maximum 999
	num_dir=$(printf "%03d" $count)
	
	mkdir ${dir}/${num_dir}

	# mp3 and cover file
	al_pic_url=$( echo $songInfo | jq '.songs[]|.al.picUrl')
	al_pic_url=${al_pic_url:1:-1}
	al_pic_url_Ext=${al_pic_url##*.}
	if [ $cookieFile ] 
	then
		AudioUrlInfo=`wget --load-cookies=$cookieFile http://localhost:3000/song/url?id=$SongId -qO -`
	else
		AudioUrlInfo=`wget http://localhost:3000/song/url?id=$SongId -qO -`
	fi

	AudioUrl=$( echo $AudioUrlInfo | jq '.data[]|.url')
	AudioUrl=${AudioUrl:1:-1}
	AudioExt=${AudioUrl##*.} 

	# lyrics
	lrcInfo=`wget http://localhost:3000/lyric?id=$SongId -qO -`
	# ja
	lrc=`echo $lrcInfo | jq '.lrc.lyric'`
	echo ${lrc} > "${dir}/${num_dir}/${ti_dir}.lrc"
	sed -i 's/\\n/\n/g' "${dir}/${num_dir}/${ti_dir}.lrc"
	# translated
	tlrc=`echo $lrcInfo | jq '.tlyric.lyric'`
	echo ${tlrc} > "${dir}/${num_dir}/${ti_dir}_zh.lrc"
	sed -i 's/\\n/\n/g' "${dir}/${num_dir}/${ti_dir}_zh.lrc"
	# romaji
	rmlrc=`echo $lrcInfo | jq '.romalrc.lyric'`
	echo ${rmlrc} > "${dir}/${num_dir}/${ti_dir}_roma.lrc"
	sed -i 's/\\n/\n/g' "${dir}/${num_dir}/${ti_dir}_roma.lrc"

	AudioFile="${ti_dir}.$AudioExt"

	# ckpt
	echo "ckpt:"
	echo "ti is $ti"
	echo "al is $al"
	echo "AudioFile name is $AudioFile"
	
	# download
	echo "downloading $ti, it's $count/$total"
	if [ "$dl_VIP" == "true" ] || [ "$IsVIP" == "0" ]
	then
		wget -qO "${dir}/${num_dir}/${AudioFile}"	${AudioUrl}
	fi
	wget -qO ${dir}/${num_dir}/AlbumPic.$al_pic_url_Ext ${al_pic_url}

	# adding info
	echo "ti:$ti" > ${dir}/${num_dir}/info.txt
    echo "tti:$tti" >> ${dir}/${num_dir}/info.txt
    echo "ar:$ar" >> ${dir}/${num_dir}/info.txt
    echo "al:$al" >> ${dir}/${num_dir}/info.txt

	# tageditor https://github.com/Martchus/tageditor
	cd $dir
	coverImg=${num_dir}/AlbumPic.${al_pic_url_Ext}
	tageditor set title="$ti" album="$al" artist="$ar" cover=${coverImg}:front-cover --files="${dir}/${num_dir}/${AudioFile}"
   	rm "${dir}/${num_dir}/${AudioFile}.bak"

	# make playlist detail
	# No 	NeteaseMusicId	title	artist	 album
	if [ "$count" == "1" ]
	then
		printf "%-6s %-50s %-50s %-50s %-20s %-10s\n" No Title Artist Album NeteaseMusicId "NeedVIP?" > ${dir}/Playlist${playlistId}Detail
	fi

	# full-width characters 
	# thanks to https://avanssion.hashnode.dev/japanese-character-validation-using-regex
	# sed 's/[一-龯ぁ-んァ-ヾー々！-￮]//g'

	# there is c_ti full-width characters in title string
	# NOTICE: to be supplemented, 
	tmp=`echo "$ti" | sed 's/[一-龯ぁ-んァ-ヾー々！-｠]//g'`
	c_ti=$(( ${#ti} - ${#tmp} ))
	tmp=`echo "$ar" | sed 's/[一-龯ぁ-んァ-ヾー々！-｠]//g'`
	c_ar=$(( ${#ar} - ${#tmp} ))
	tmp=`echo "$al" | sed 's/[一-龯ぁ-んァ-ヾー々！-｠]//g'`
	c_al=$(( ${#al} - ${#tmp} ))
	
	n_ti=$(( 50+$c_ti ))
	n_ar=$(( 50+$c_ar ))
	n_al=$(( 50+$c_al ))

	if [ "$IsVIP" == "1" ]
	then
		VIP_Info=yes
	else
		VIP_Info=No
	fi

	printf "%-6s %-${n_ti}s %-${n_ar}s %-${n_al}s %-20s %-10s\n" "${num_dir}" "$ti" "$ar" "$al" "$SongId" "$VIP_Info" >> ${dir}/Playlist${playlistId}Detail
			
done < $SongIdFile

rm $SongIdFile

echo -e "\nDownload complete, $total songs downloaded"
echo -e "Check playlist${playlistId}Detail"


