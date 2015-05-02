#!/bin/sh

: ${OSX_SDKVERSION:=`xcodebuild -showsdks | grep osx | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`}
: ${XCODE_ROOT:=`xcode-select -print-path`}

: ${SRCDIR:=`pwd`}
: ${OSXBUILDDIR:=`pwd`/osx/build}
: ${PREFIXDIR:=`pwd`/osx/prefix}
: ${OSXFRAMEWORKDIR:=`pwd`/osx/framework}
: ${COMPILER:="clang"}

: ${LUA_VERSION:=5.1.5}

#===============================================================================

INTEL_DEV_CMD="xcrun --sdk macosx"

X86_64_LIB=$OSXBUILDDIR/lib_luajit_x86_64.a

OSXSYSROOT=$XCODE_ROOT/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$IPHONE_SDKVERSION.sdk

FILES_INC="$SRCDIR/src/lua.h $SRCDIR/src/lualib.h $SRCDIR/src/lauxlib.h $SRCDIR/src/luaconf.h $SRCDIR/src/lua.hpp $SRCDIR/src/luajit.h"

EXTRA_CFLAGS="-DLUA_USE_DLOPEN"

compile_framework() {
FRAMEWORK_BUNDLE=$1/LuaJIT.framework
FRAMEWORK_VERSION=A
FRAMEWORK_NAME=LuaJIT

shift;

rm -rf $FRAMEWORK_BUNDLE

mkdir -p $FRAMEWORK_BUNDLE
mkdir -p $FRAMEWORK_BUNDLE/Versions
mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
$INTEL_DEV_CMD lipo -create $@ -output "$FRAMEWORK_INSTALL_NAME" || exit

echo "Framework: Copying includes..."
cp -r $FILES_INC $FRAMEWORK_BUNDLE/Headers/

echo "Framework: Creating plist..."
cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleDevelopmentRegion</key>
<string>English</string>
<key>CFBundleExecutable</key>
<string>${FRAMEWORK_NAME}</string>
<key>CFBundleIdentifier</key>
<string>org.luajit</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundlePackageType</key>
<string>FMWK</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF
}


mkdir -p $OSXBUILDDIR

compile_x86_64() {
echo compiling x86_64 ...
ISDKF="-arch x86_64 -isysroot $OSXSYSROOT $EXTRA_CFLAGS"
make -C $SRCDIR/src clean libluajit.a HOST_CC="$COMPILER -arch x86_64"
cp $SRCDIR/src/libluajit.a $OSXBUILDDIR/lib_luajit_x86_64.a
}

compile_x86_64

echo build osx framework ...
compile_framework $OSXFRAMEWORKDIR $X86_64_LIB

echo framework will be at $OSXFRAMEWORKDIR
echo success!