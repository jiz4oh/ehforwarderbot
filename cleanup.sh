#!/bin/sh

# 查找当前目录下修改时间超过1天的文件（不包括目录）并删除
# -maxdepth 1: 只查找当前目录，不递归子目录
# -type f: 只查找文件
# -mtime +0: 查找修改时间在24小时之前的文件 (0表示整天，+0表示超过1天)
# -delete: 删除找到的文件

find /comwechat/Files/wxid_* -maxdepth 1 -type f -mtime +0 -delete
find /comwechat/Files/wxid_*/FileStorage/Cache -type f -mtime +0 -delete
find /comwechat/Files/wxid_*/FileStorage/Sns/Cache -type f -mtime +0 -delete
