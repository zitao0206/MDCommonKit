#!/bin/sh

export LANG=en_US.UTF-8

package_framework() {
    podName=$1
    # 1.0.4
    version=$2
    
    new_version=$version

    #echo ${packageDIR}
    # 替换版本号
    sed -i '' "s/=\ smart_version/=\ \'$version\'/g" ./${podName}.podspec

    # 开始打包
    pod package --spec-sources=https://github.com/Leon0206/MDSpecs.git,https://cdn.cocoapods.org/ --no-mangle --embedded --force --exclude-deps --configuration=Debug ./${podName}.podspec
    if [ $? -ne 0 ]; then
        echo '打包失败'
        # 恢复版本号
        sed -i '' "s/=\ \'$version\'/=\ smart_version/g" ./${podName}.podspec
        exit 1
    fi
    # 恢复版本号
    sed -i '' "s/=\ \'$version\'/=\ smart_version/g" ./${podName}.podspec

    rm -rf ./Framework/*

    if [ ! -d "./Framework/${new_version}" ]; then
        mkdir -p ./Framework/${new_version}
    fi

    # 拷贝Framework
    cp -R ./${podName}-$version/ios/${podName}.embeddedframework/*.framework ./Framework/${new_version}/
    # 移除打包临时目录
    rm -rf ./${podName}-$version
}

packageDIR=`pwd`

podName=${packageDIR##*/}

version=`git describe --abbrev=0 --tags 2>/dev/null`

package_framework $podName $version

echo "开始准备提交和发步："

sleep 2

sh submitHelper.sh
