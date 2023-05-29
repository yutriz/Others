#!/usr/bin/bash 

# base on cloudmusic nodejs API
# https://github.com/Binaryify/NeteaseCloudMusicApi
# I used to use curl to get the json so I can extract infomations through pipe, but I dunno why curl keeps showing  "curl: (3) URL using bad/illegal format or missing URL", so wget , dumb of me 

# note: same artist, same song title, different album 
# 	    maybe later
# WARNING: IF AN ERROR OCCURRED, PLEASE DOWNLOAD MANUALLY 


echo "usage: get_playlist_songs.sh playlist_id"

playlist_adr="http://localhost:3000/playlist/detail?id=$1"
echo gaining info from $playlist_adr

SongIdFile=playlist$1

curl $playlist_adr | jq '.playlist.trackIds[] | .id' > $SongIdFile
total=`cat $SongIdFile | wc -l`
count=0
while read SongId 
do
	count=$(($count+1))
	echo "${count}/$total"
# song details
	wget -qO tmp "http://localhost:3000/song/detail?ids=$SongId" 
	ti=$( cat tmp | jq '.songs[]|.name' )
	al=$( cat tmp | jq '.songs[]|.al.name' )
	# tti = translated title
	tti=$( cat tmp | jq '.songs[]|.tns' | sed 's/\[//g;s/\]//g' )
	
	if [ "$tti" != "null" ]
	then
		# why? coz [SpaceSpace"title"]
		tti=${tti:3:-1}
	fi


	# multi artists 
	ars=$( cat tmp | jq '.songs[]|.ar[]|.name' | sed 's/\"//g' )
	ar=
	for i in $ars
	do
		ar=${ar}\&${i}
	done
	ar=${ar/\&/}
	ti=${ti:1:-1}
	al=${al:1:-1}

	# considering song title may contain ", and it becomes \" when extracted from json file 
	# more situation?
	# newest: windows path can not contain \ / : " ? < > |

	ti_d=$( echo $ti | sed 's/\\"/〝/g;s/\"/〝/g;s/\\?/？/g;s/\?/？/g;s/\\!/！/g;s/\!/！/g;s/\\:/：/g;s/\:/：/g;s/\\</＜/g;s/\\>/＞/g' )
	al_d=$( echo $al | sed 's/\\"/〝/g;s/\"/〝/g;s/\\?/？/g;s/\?/？/g;s/\\!/！/g;s/\!/！/g;s/\\:/：/g;s/\:/：/g;s/\\</＜/g;s/\\>/＞/g' )



	# don not like space in filenames in linux 
	ti_d=${ti_d// /_}
	ar_d=${ar// /_}
	# the directory doesn't contain album name 
	al_d=${al// /_}
		
	dir=${ar_d}_${ti_d}
	
	# in Windows, folder name ended with "." brings problem
	while [ "${dir: -1}" == "." ]
	do
		dir=${dir:0:-1}
	done

	mkdir $dir

	al_pic_url=$( cat tmp | jq '.songs[]|.al.picUrl')
# resource url
	wget -qO tmp "http://localhost:3000/song/url?id=$SongId"
	mp3Url=$( cat tmp | jq '.data[]|.url')

# lyrics
	wget -qO tmp "http://localhost:3000/lyric?id=$SongId"
	# jap, the default lyrics, ${name}.mp3 and ${name}.lrc, so it can be shown
	lrc=`cat tmp | jq '.lrc.lyric'`
	echo ${lrc:1:-1} > ${dir}\/${dir}.lrc
	sed -i 's/\\n/\n/g' ${dir}\/${dir}.lrc
	# translated 
	lrc=`cat tmp | jq '.tlyric.lyric'` 
	echo ${lrc:1:-1} > ${dir}\/${dir}_zh.lrc
	sed -i 's/\\n/\n/g' ${dir}\/${dir}_zh.lrc
	# roma 
	lrc=`cat tmp | jq '.romalrc.lyric'`
	echo ${lrc:1:-1} > ${dir}\/${dir}_roma.lrc
	sed -i 's/\\n/\n/g' ${dir}\/${dir}_roma.lrc
	
	# downloads begin
	

	echo "downloading ${dir} ..."

	wget -qO "${dir}/${dir}.mp3" ${mp3Url:1:-1}
	wget -qO "${dir}/${dir}_AlbumPic.jpg" ${al_pic_url:1:-1}
	echo "ti:$ti" > ${dir}\/info.txt
	echo "tti:$tti" >> ${dir}\/info.txt
	echo "ar:$ar" >> ${dir}\/info.txt
	echo "al:$al" >> ${dir}\/info.txt

	# eyeD3 add tags 
	eyeD3 -a "$ar" ${dir}\/${dir}.mp3
	eyeD3 -A "$al" ${dir}\/${dir}.mp3
	eyeD3 -t "$ti" ${dir}\/${dir}.mp3
	eyeD3 --add-image ${dir}\/${dir}_AlbumPic.jpg:FRONT_COVER ${dir}\/${dir}.mp3


	# make a list  
	# NeteaseMusicId	title	artist
	echo -e "NeteaseMusicId\t\tTitle\t\tArtist\t\talbum" > Playlist$1Details
	echo -e "$SongId\t\t$ti\t\t$ar\t\t$al" >>  Playlist$1Details	

done < $SongIdFile

rm tmp
rm $SongIdFile 
