#!/bin/bash

hosts=("master1-admin" "node1-monitor" "node2-osd")

username="root"
password="Qwer1234"
port=22
timeout=2

# 检查是否安装 expect
if ! rpm -q expect &>/dev/null; then
    echo "正在安装expect..."
    yum -y install expect &>/dev/null
    # 再次检查是否安装成功
    if ! rpm -q expect &>/dev/null; then
        echo "安装expect失败，请手动安装"
        exit 1
    fi
fi
for i in "${hosts[@]}"; do
    {
        ping -c1 -W1 $i &>/dev/null
        if [ $? -eq 0 ]; then
            (
                timeout $timeout /usr/bin/expect <<-EOF
					spawn ssh-copy-id $username@$i -p $port
					expect {
						"yes/no"    {send "yes\r";exp_continue}
						"password" {send "$password\r"} 	
					}
					expect eof
				EOF
            ) &>/dev/null

            timeout $timeout ssh $i echo "$i success"
            if [ $? -ne 0 ]; then
                # 如果 SSH 连接失败
                echo "SSH连接失败，请检查主机 $i"
            fi
        else
            # 如果主机不可达
            echo "主机 $i 不可达"
        fi
    }
done
