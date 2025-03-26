FROM python:3.11-alpine

ENV LANG C.UTF-8
ENV TZ 'Asia/Shanghai'
ENV EFB_DATA_PATH /data/
ENV EFB_PARAMS ""
ENV EFB_PROFILE "default"
ENV HTTPS_PROXY ""

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

RUN apk add --no-cache tzdata ca-certificates \
       gifsicle ffmpeg libmagic python3 \
       tiff libwebp freetype lcms2 openjpeg py3-olefile openblas \
       py3-numpy py3-pillow py3-cryptography py3-decorator cairo py3-pip
RUN apk add --no-cache --virtual .build-deps git build-base gcc python3-dev \
    && pip3 install pysocks ehforwarderbot efb-telegram-master --break-system-packages \
    && pip3 install git+https://github.com/Ovler-Young/efb-wechat-slave.git --break-system-packages \
    && apk del .build-deps

#{{{comwechat
RUN set -ex; \
    apk --update upgrade; \
    apk --update add --no-cache python3-dev py3-pillow py3-ruamel.yaml libmagic ffmpeg git gcc zlib-dev jpeg-dev musl-dev libffi-dev openssl-dev libwebp-dev zbar-dev

RUN pip3 install urllib3==1.26.15; \
    pip3 install --no-deps --force-reinstall rich Pillow; \
    pip3 install --ignore-installed PyYAML TgCrypto;

RUN pip3 install git+https://github.com/QQ-War/efb-telegram-master.git; \
    pip3 install ehforwarderbot python-telegram-bot; \
    pip3 install git+https://github.com/0honus0/python-comwechatrobot-http.git; \
    pip3 install git+https://github.com/jiz4oh/efb-wechat-comwechat-slave.git; \
    pip3 install git+https://github.com/QQ-War/efb-keyword-reply.git; \
    pip3 install git+https://github.com/QQ-War/efb_message_merge.git;
#}}}

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
