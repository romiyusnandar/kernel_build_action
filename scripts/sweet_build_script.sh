#!/usr/bin/env bash

# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel

clang() {
    rm -rf clang
    echo "Cloning clang"
    if [ ! -d "clang" ]; then
      REMOTE="https://gitlab.com"
      TARGET="RooGhz720"
      REPO="android_prebuilts_clang_host_linux-x86_clang-r487747b"
      BRANCH="master"
        git clone --depth=1 -b "$BRANCH" "$REMOTE"/"$TARGET"/"$REPO" "${PWD}"/clang
		git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git "${PWD}"/clang/aarch64-linux-android-4.9
		git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git "${PWD}"/clang/arm-linux-androideabi-4.9
        KBUILD_COMPILER_STRING="Proton clang 15.0"
        PATH="${PWD}/clang/bin:${PATH}"
    fi
    sudo apt install -y ccache
    echo "Done"
}

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=1
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST="romi.yusna"
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="orion-server"
export KBUILD_BUILD_USER
DEVICE="Redmi Note 10 Pro"
export DEVICE
CODENAME="sweet"
export CODENAME
# DEFCONFIG=""
#DEFCONFIG_COMMON="sweet_defconfig"
DEFCONFIG_DEVICE="vendor/sweet_user_defconfig"
# export DEFCONFIG_COMMON
export DEFCONFIG_DEVICE
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=STABLE
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${token}"/sendMessage -d chat_id="${chat_id}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${token}"/sendDocument \
        -F "chat_id=${chat_id}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# Send Build Info
sendinfo() {
    tg "
• sirCompiler Action •
*Building on*: \`Github actions\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO}/commit/${COMMIT_HASH})
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build Status*: \`${STATUS}\`"
}

# Push kernel to channel
push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}

# Catch Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}

# Compile
compile() {

    if [ -d "out" ]; then
        rm -rf out && mkdir -p out
    fi
    # git remote add addon https://github.com/RooGhz720/RooGhz720.git
    # git fetch addon
    # sleep 5
    # git cherry-pick 3b7da833ca83852ad3c60972a9ef6cdefcba8795 ##miui pick
    # git cherry-pick --skip
    # echo "berhasil switch ke MIUI"
    # sleep 2

    make O=out ARCH="${ARCH}"
    # make "$DEFCONFIG_COMMON" O=out
    make "$DEFCONFIG_DEVICE" O=out
    make -j$(nproc --all) O=out \
                              ARCH=arm64 \
                              LLVM=1 \
                              LLVM_IAS=1 \
                              AR=llvm-ar \
                              NM=llvm-nm \
                              LD=ld.lld \
                              OBJCOPY=llvm-objcopy \
                              OBJDUMP=llvm-objdump \
                              STRIP=llvm-strip \
                              CC=clang \
                              CROSS_COMPILE=aarch64-linux-gnu- \
                              CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    if ! [ -a "$IMAGE" ]; then
        finderr
        exit 1
    fi

    git clone https://github.com/romiyusnandar/Anykernel3 -b sweet AnyKernel
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtb.img AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 test-kernel-"${BRANCH}"-"${CODENAME}"-"${DATE}".zip ./*
    cd ..
}

clang
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
