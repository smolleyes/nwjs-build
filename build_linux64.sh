#!/bin/bash
#for ubuntu linux64 atm. run : `./build_linux64.sh nw18`

if [ -z "$1" ]
  then
    echo "Error: specify a target branch as first argument, e.g: nw18"
    exit 0
else
    MAIN=$1
fi

echo "Building nwjs from sources, with ffmpeg patches [branch: $MAIN]"

# create main dir
mkdir -p nwjs-build
cd nwjs-build # nwjs-build

# get depot tool
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"
export GYP_DEFINES=target_arch=x64

# get nwjs sources
mkdir -p nwjs
cd nwjs # nwjs-build/nwjs

# generate .gclient
echo -e "solutions = [
  { \"name\"        : \"src\",
    \"url\"         : \"https://github.com/nwjs/chromium.src.git@origin/$MAIN\",
    \"deps_file\"   : \"DEPS\",
    \"managed\"     : True,
    \"custom_deps\" : {
        \"src/third_party/WebKit/LayoutTests\": None,
        \"src/chrome_frame/tools/test/reference_build/chrome\": None,
        \"src/chrome_frame/tools/test/reference_build/chrome_win\": None,
        \"src/chrome/tools/test/reference_build/chrome\": None,
        \"src/chrome/tools/test/reference_build/chrome_linux\": None,
        \"src/chrome/tools/test/reference_build/chrome_mac\": None,
        \"src/chrome/tools/test/reference_build/chrome_win\": None,
    },
    \"safesync_url\": \"\",
  },
]
cache_dir = None" > .gclient

# get repos
git clone https://github.com/nwjs/nw.js.git src/content/nw 
cd src/content/nw
git checkout $MAIN
cd ../../.. # nwjs-build/nwjs

git clone https://github.com/nwjs/node src/third_party/node-nw
cd src/third_party/node-nw
git checkout $MAIN
cd ../../.. # nwjs-build/nwjs

git clone https://github.com/nwjs/v8 src/v8
cd src/v8
git checkout $MAIN
cd ../.. # nwjs-build/nwjs

# get source code
gclient sync --with_branch_heads --nohooks
./build/install-build-deps.sh
gclient runhooks

# build ninja conf
cd src
gn gen out/nw --args='is_debug=false is_component_ffmpeg=true target_cpu="x64" nwjs_sdk=true enable_nacl=false ffmpeg_branding="Chrome" proprietary_codecs=true enable_ac3_eac3_audio_demuxing=true enable_hevc_demuxing=true is_official_build=true enable_mse_mpeg2ts_stream_parser=true'

cd ../../.. # ./

# replace python build script lines
echo -e "434,435c434,436
<       '--enable-demuxer=ogg,matroska,wav,flac,mp3,mov',
<       '--enable-parser=opus,vorbis,flac,mpegaudio',
---
>       '--enable-decoder=aac,ac3,aac3,h264,mp1,mp2,mp3,mpeg4,mpegvideo,hevc,flv,dca,flac',
>       '--enable-demuxer=aac,ac3,h264,mp3,mp4,m4v,matroska,wav,mpegvideo,mpegts,mov,avi,flv,dts,dtshd,vc1,flac,ogg,mov',
>       '--enable-parser=aac,ac3,aac3,h261,h263,h264,opus,vorbis,mepgvideo,mpeg4video,mpegaudio,dca,hevc,vc1,flac'," > build_ffmpeg.patch


patch -p1 nwjs-build/nwjs/src/third_party/ffmpeg/chromium/scripts/build_ffmpeg.py < build_ffmpeg.patch

# clean patch files
rm build_ffmpeg.patch

cd nwjs-build/nwjs/src # nwjs-build/nwjs/src

# rebuild ffmpeg conf files
cd third_party/ffmpeg
./chromium/scripts/build_ffmpeg.py linux x64 --config-only

# build ffmpeg
cd build.x64.linux/ChromeOS
make

# trick nwjs into thinking it's chrome, not chromeos build (enables avi files)
cd ..
rm -r Chrome
cp -R ChromeOS Chrome
cd ..

# copy ffmpeg conf
./chromium/scripts/copy_config.sh 

# generate gyp for ffmpeg build
./chromium/scripts/generate_gn.py

cd ../.. # nwjs-build/nwjs/src

# generate ninja build files
GYP_CHROMIUM_NO_ACTION=0 ./build/gyp_chromium -I third_party/node-nw/common.gypi third_party/node-nw/node.gyp

# build nwjs
ninja -C out/nw nwjs

# build node
ninja -C out/Release node

# copy node lib
ninja -C out/nw copy_node

# strip binaries & libs
cd out/nw # nwjs-build/nwjs/src/out/nw
strip nw
strip lib/*.so

# move required files to out/dist
cd .. #nwjs-build/nwjs/src/out
mkdir -p dist
cp -R nw/nw nw/lib nw/locales nw/icudtl.dat nw/natives_blob.bin nw/nw_100_percent.pak nw/nw_200_percent.pak nw/resources.pak nw/snapshot_blob.bin dist/
rm -rf dist/lib/*.TOC

echo "See built nwjs in: nwjs-build/nwjs/src/out/dist"
