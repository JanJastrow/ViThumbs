#!/bin/sh

if [ -z "$1" ]; then
	echo "usage: ./vithumbs.sh INPUT [COLS=5] [ROWS=5] [SIZE=1600]"
	exit
fi

# Input variables
INPUT=$1

if [ ! -f "$INPUT" ]; then
	echo "File not found."
	exit 1
fi

COLS=$2
if [ -z "$COLS" ]; then
	COLS=5
fi
ROWS=$3
if [ -z "$ROWS" ]; then
	ROWS=5
fi
SIZE=$4
if [ -z "$SIZE" ]; then
	SIZE=1600
fi

FILE_SUFFIX="_thumbs"

# Design variables
INFO_TEXTCOLOR="0xEEEEEE"
INFO_BGCOLOR="0x282828"
INFO_FONTSIZE=20
INFO_LINESPACING=5
INFO_HEIGHT=130
FONTFILE=""

# Render text in system monospace font if no other is defined
if [ -z "$FONTFILE" ]; then
	FONT="font=Mono"
else
	FONT="fontfile=$FONTFILE"
fi

FFMPEG_VERBOSITY="-hide_banner -loglevel error"
NFRAMES=$(echo "scale=0;$COLS*$ROWS" | bc)
DURATION=$(ffmpeg -i "$INPUT" 2>&1 | grep "Duration"| cut -d ' ' -f 4 | sed s/,// | sed 's@\..*@@g' | awk '{ split($1, A, ":"); split(A[3], B, "."); print 3600*A[1] + 60*A[2] + B[1] }')
DURX=$(ffmpeg -i "$INPUT" 2>&1 | grep Duration | awk '{print $2}' | tr -d ,)
FILESIZE=$(du -sm "$INPUT" | awk '{print $1}')
VIDEO_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT")
VIDEO_FPS=$(echo "scale=2; $(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")" | bc)
VIDEO_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT")
VIDEO_AR=$(ffprobe -v error -select_streams v:0 -show_entries stream=display_aspect_ratio -of default=noprint_wrappers=1:nokey=1 "$INPUT")
VIDEO_BITRATE=$(echo $(ffprobe -v error -select_streams v:0 -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT") / 1000 | bc)
AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT")
AUDIO_CODEC_TAG=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_tag_string -of default=noprint_wrappers=1:nokey=1 "$INPUT")
AUDIO_SAMPLERATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")
AUDIO_BITRATE=$(echo $(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT") / 1000 | bc)
AUDIO_CHANNELS=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$INPUT")

TMPDIR="/tmp/thumbnails-${RANDOM}/"
mkdir $TMPDIR

echo "Extracting thumbnails…"
for (( VARIABLE=0; VARIABLE<NFRAMES; VARIABLE++ ))
	do
	OFFSET=$(echo "scale=2;$VARIABLE*$DURATION/$NFRAMES+$DURATION/$NFRAMES/2" | bc)

	# Create thumbnails
	ffmpeg -start_at_zero -copyts -ss $OFFSET $FFMPEG_VERBOSITY -i "$INPUT" \
	-vf "drawtext=$FONT:fontsize=60:fontcolor=0xEEEEEE::shadowcolor=0x111111:shadowx=2:shadowy=2:x=(W-tw)/40:y=H-th-20:text='%{pts\:gmtime\:0\:%H\\\\\\:%M\\\\\:%S}'" \
	-vframes 1 ${TMPDIR}$(printf "%04d" $VARIABLE).png
done

# Merge thumbnails into tile image
ffmpeg -pattern_type glob $FFMPEG_VERBOSITY -i "${TMPDIR}*.png" -filter_complex tile=${COLS}x${ROWS}:margin=5:padding=5:color=white ${TMPDIR}tiled.png

# Output metadata to file
echo "File Name: $INPUT" >>${TMPDIR}metadata.txt
echo "File Size: $FILESIZE MByte" >>${TMPDIR}metadata.txt
echo "Duration:  $DURX" >>${TMPDIR}metadata.txt
echo "Video:     $VIDEO_RES ($VIDEO_AR) • $VIDEO_BITRATE kbps • $VIDEO_CODEC • $VIDEO_FPS fps" >>${TMPDIR}metadata.txt
echo "Audio:     $AUDIO_CODEC/$AUDIO_CODEC_TAG • $AUDIO_SAMPLERATE kHz • $AUDIO_BITRATE kbps • $AUDIO_CHANNELS channel" >>${TMPDIR}metadata.txt

# Get dimensions of tile image
thewidth=$(ffmpeg -i ${TMPDIR}tiled.png 2>&1 |grep Video|awk '{ split( $6, pieces,  /[x,]/ ) ; print pieces[1] }')
theheight=$(ffmpeg -i ${TMPDIR}tiled.png 2>&1 |grep Video|awk '{ split( $6, pieces,  /[x,]/ ) ; print pieces[2] }')

# Redefine height & scale (according to $SIZE)
scaledheight=$(echo "scale=0;$theheight*$SIZE/$thewidth" | bc)
ffmpeg $FFMPEG_VERBOSITY -i ${TMPDIR}tiled.png -vf scale=${SIZE}x${scaledheight} -vframes 1 ${TMPDIR}tiled_resized.png

# Add space to the top of the image
finalheight=$(echo "$scaledheight+$INFO_HEIGHT" | bc)

echo "Merging thumbnails and adding meta data…"

# Add Metadata
ffmpeg -f lavfi -i color=$INFO_BGCOLOR:${SIZE}x${finalheight} $FFMPEG_VERBOSITY -i ${TMPDIR}tiled_resized.png \
-filter_complex "[0:v][1:v] overlay=0:$INFO_HEIGHT,drawtext=$FONT:fontsize=$INFO_FONTSIZE:fontcolor=$INFO_TEXTCOLOR:line_spacing=$INFO_LINESPACING:x=12:y=12:textfile=${TMPDIR}metadata.txt" \
-vframes 1 -q:v 2 "${INPUT}${FILE_SUFFIX}.jpg"

echo "Done ✅"

# Clean tempfiles
rm -r $TMPDIR