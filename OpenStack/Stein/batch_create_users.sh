#!/bin/bash
# 用户从user.txt中获取
for n in `cat user.txt`
do
    # 每个人单独的项目不影响其他人
    # openstack project create --domain default $n
    # 随机密码
    pass=`date +%N | md5sum |awk '{print $1}'`
    openstack user create --domain default --password $pass $n
    openstack role add --project {PROJECT} --user {USER_NAME} {ROLE}
    # 导出用户和密码
    echo $n:$pass >> user_pass.txt
done