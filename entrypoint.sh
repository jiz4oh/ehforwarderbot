#!/bin/sh

# 启动 crond 服务
crond

PARAMS=

if [ -n "$EFB_PROFILE" ]; then
  PARAMS="$PARAMS -p $EFB_PROFILE"
fi

PARAMS="$PARAMS $EFB_PARAMS"

eval "ehforwarderbot $PARAMS"
