#!/bin/sh

set -ex

export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$(uname -m)"

REPO="https://github.com/emuplace/sudachi.emuplace.app/releases/download/v1.0.15/latest.zip"
VERSION="1.0.15"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"

if [ "$ARCH" = 'x86_64' ]; then
	if [ "$1" = 'v3' ]; then
		echo "Making x86-64-v3 optimized build of sudachi"
		ARCH="${ARCH}_v3"
		ARCH_FLAGS="-march=x86-64-v3 -O3"
  	elif [ "$1" = 'steamdeck' ]; then
		echo "Making Steam Deck optimized build of sudachi"
		ARCH="znver2"
		ARCH_FLAGS="-march=znver2 -O3"
	else
		echo "Making x86-64 generic build of sudachi"
		ARCH_FLAGS="-march=x86-64 -mtune=generic -O3"
	fi
else
	echo "Making aarch64 build of sudachi"
	ARCH_FLAGS="-march=armv8-a -mtune=generic -O3"
fi

if [ "$2" = 'debug' ]; then
	DEBUG=" -DCMAKE_BUILD_TYPE=Debug "
fi

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"

# BUILD SUDACHI
wget --no-verbose --show-progress --progress=dot:mega $REPO
unzip -q latest -d sudachi
dos2unix sudachi/setup.sh
sed -i -e 's/s\\c/s\/c/' sudachi/setup.sh

(
	cd ./sudachi
	bash setup.sh
	#git submodule update --init --recursive -j$(nproc)

	#Replaces 'boost::asio::io_service' with 'boost::asio::io_context' for compatibility with Boost.ASIO versions 1.74.0 and later
	find src -type f -name '*.cpp' -exec sed -i 's/boost::asio::io_service/boost::asio::io_context/g' {} \;

 	# Apply patches
  	unix2dos ../patches/fmt11-support.patch
  	patch -p1 -l --binary < ../patches/fmt11-support.patch

   	sed -i -e 's/FFmpeg 4.3 REQUIRED QUIET COMPONENTS/FFmpeg REQUIRED QUIET COMPONENTS/' CMakeLists.txt
    sed -i -e 's/SDL_GetWindowProperties(window)/SDL_GetWindowProperties(render_window)/g' src/sudachi_cmd/emu_window/emu_window_sdl3_vk.cpp
    #cd externals/xbyak && git checkout a1ac3750f9a639b5a6c6d6c7da4259b8d6790989 && cd ../..
    #sed -i -e 's/1318ab14aae14db20085441cd71366891a9c9d0c/c82f74667287d3dc386bce81e44964370c91a289/' vcpkg.json

	mkdir build
	cd build
	cmake .. -GNinja $DEBUG \
		-DSUDACHI_USE_BUNDLED_VCPKG=OFF \
		-DSUDACHI_USE_BUNDLED_QT=OFF \
		-DUSE_SYSTEM_QT=ON \
		-DSUDACHI_USE_BUNDLED_FFMPEG=ON \
		-DSUDACHI_USE_BUNDLED_SDL3=ON \
		-DSUDACHI_USE_EXTERNAL_SDL3=OFF \
		-DSUDACHI_TESTS=OFF \
		-DSUDACHI_USE_QT_WEB_ENGINE=OFF \
		-DENABLE_QT_TRANSLATION=ON \
		-DUSE_DISCORD_PRESENCE=OFF \
  		-DSUDACHI_ENABLE_LTO=ON \
		-DBUNDLE_SPEEX=ON \
		-DSUDACHI_USE_FASTER_LD=OFF \
		-DCMAKE_INSTALL_PREFIX=/usr \
  		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_CXX_FLAGS="$ARCH_FLAGS -Wno-error -w" \
		-DCMAKE_C_FLAGS="$ARCH_FLAGS" \
		-DCMAKE_SYSTEM_PROCESSOR="$(uname -m)" \
		-DCMAKE_BUILD_TYPE=Release
	ninja
	sudo ninja install
	echo "$VERSION" >~/version
	cd ~
)
rm -rf ./sudachi
VERSION="$(cat ~/version)"

# NOW MAKE APPIMAGE
mkdir ./AppDir
cd ./AppDir

cp -v /usr/share/applications/org.sudachi_emu.sudachi.desktop ./sudachi.desktop
cp -v /usr/share/icons/hicolor/scalable/apps/org.sudachi_emu.sudachi.svg ./sudachi.svg
ln -s ./sudachi.svg ./.DirIcon

# Bundle all libs
wget --retry-connrefused --tries=30 "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -a -- ./lib4bin -p -v -e -s -k \
	/usr/bin/sudachi* \
	/usr/lib/libGLX* \
	/usr/lib/libGL.so* \
	/usr/lib/libEGL* \
	/usr/lib/dri/* \
	/usr/lib/vdpau/* \
	/usr/lib/libvulkan* \
	/usr/lib/libXss.so* \
	/usr/lib/libdecor-0.so* \
	/usr/lib/libgamemode.so* \
 	/usr/lib/qt5/plugins/audio/* \
	/usr/lib/qt5/plugins/bearer/* \
	/usr/lib/qt5/plugins/imageformats/* \
	/usr/lib/qt5/plugins/iconengines/* \
	/usr/lib/qt5/plugins/platforms/* \
	/usr/lib/qt5/plugins/platformthemes/* \
	/usr/lib/qt5/plugins/platforminputcontexts/* \
	/usr/lib/qt5/plugins/styles/* \
	/usr/lib/qt5/plugins/xcbglintegrations/* \
	/usr/lib/qt5/plugins/wayland-*/* \
	/usr/lib/qt6/plugins/audio/* \
	/usr/lib/qt6/plugins/bearer/* \
	/usr/lib/qt6/plugins/imageformats/* \
	/usr/lib/qt6/plugins/iconengines/* \
	/usr/lib/qt6/plugins/platforms/* \
	/usr/lib/qt6/plugins/platformthemes/* \
	/usr/lib/qt6/plugins/platforminputcontexts/* \
	/usr/lib/qt6/plugins/styles/* \
	/usr/lib/qt6/plugins/xcbglintegrations/* \
	/usr/lib/qt6/plugins/wayland-*/* \
	/usr/lib/pulseaudio/* \
	/usr/lib/pipewire-0.3/* \
	/usr/lib/spa-0.2/*/* \
	/usr/lib/alsa-lib/*

# Prepare sharun
if [ "$ARCH" = 'aarch64' ]; then
	# allow the host vulkan to be used for aarch64 given the sed situation
	echo 'SHARUN_ALLOW_SYS_VKICD=1' > ./.env
fi
ln ./sharun ./AppRun
./sharun -g

# turn appdir into appimage
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

# Keep the mount point (speeds up launch time)
sed -i 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
./uruntime --appimage-addupdinfo "$UPINFO"

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S26 -B32 \
	--header uruntime \
	-i ./AppDir -o Sudachi-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake *.AppImage -u *.AppImage
echo "All Done!"
