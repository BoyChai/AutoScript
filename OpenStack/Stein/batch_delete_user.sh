#!/bin/bash
# 用户从user.txt中获取
for n in `cat user.txt`
do
    # 先删除角色关联
    # openstack role remove --project default --user $n user
    # 删除项目
    # openstack project delete $n
    # 删除用户
    openstack user delete $n
done