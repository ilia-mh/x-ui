#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}error: ${plain} This script must be run as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Failed to detect schema, use default schema: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32 bit system(x86), please use 64 bit system(x86_64)"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}please use CentOS 7 or later system! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}please use Ubuntu 16 or later system! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}please use Debian 8 or later system! ${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, it is necessary to forcibly modify the port and account password after the installation/update is completed. ${plain}"
    read -p "Confirm whether to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm setting, setting${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Account password setting completed${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Panel port setting completed${plain}"
    else
        echo -e "${red} Cancelled, all setting items are default settings, please modify in time ${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/ilia-mh/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}detect x-ui Version failed, possibly out of Github API limit, please try again later, or specify manually x-ui Version installation ${plain}"
            exit 1
        fi
        echo -e "detected x-ui The latest version of：${last_version}, start installation" https://github.com/ilia-mh/x-ui/archive/refs/tags/${last_version}.tar.gz
        wget -N --no-check-certificate -O /usr/local/x-ui-${last_version}.tar.gz https://github.com/ilia-mh/x-ui/archive/refs/tags/${last_version}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}download x-ui Failed, please make sure your server is able to download Github document ${plain}"
            exit 1
        fi
    else
        last_version=$(curl -Ls "https://api.github.com/repos/ilia-mh/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        url="https://github.com/ilia-mh/x-ui/archive/refs/tags/${last_version}.tar.gz"
        echo -e "start installation x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-${last_version}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}download x-ui v$1 failed, make sure this version exists ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/ilia-mh/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    tar zxvf x-ui-${last_version}.tar.gz
    rm x-ui-${last_version}.tar.gz -f
    cd x-ui-${last_version}
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/ilia-mh/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui-${last_version}/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete and the panel is launched，"
    echo -e ""
    echo -e "x-ui Scripts Available: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - management menu"
    echo -e "x-ui start        - start x-ui Panel"
    echo -e "x-ui stop         - stop x-ui Panel"
    echo -e "x-ui restart      - restart x-ui Panel"
    echo -e "x-ui status       - check x-ui status"
    echo -e "x-ui enable       - setup x-ui Auto-start"
    echo -e "x-ui disable      - disable x-ui Auto-start"
    echo -e "x-ui log          - check x-ui logs"
    echo -e "x-ui v2-ui        - Migrate v2-ui account data to x-ui"
    echo -e "x-ui update       - update x-ui"
    echo -e "x-ui install      - Install x-ui"
    echo -e "x-ui uninstall    - uninstall x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}Start Installation${plain}"
install_base
install_x-ui $1
