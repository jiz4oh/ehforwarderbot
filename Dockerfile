# Stage 1: Builder stage - Install build dependencies and Python packages
FROM python:3.11-alpine AS builder

ENV LANG C.UTF-8
ENV TZ 'Asia/Shanghai'

# Install build-time dependencies for apk packages and pip packages
RUN set -ex; \
    apk add --no-cache --update \
        python3-dev \
        py3-pillow \
        py3-ruamel.yaml \
        git \
        gcc \
        musl-dev \
        zlib-dev \
        jpeg-dev \
        libffi-dev \
        openssl-dev \
        libwebp-dev \
        zbar-dev; \
    # Install python packages using pip with --no-cache-dir
    pip3 install --no-cache-dir urllib3==1.26.15; \
    # Install/reinstall rich and Pillow from pip (as per original Dockerfile intent)
    # Note: Pillow might be installed via apk (py3-pillow) and pip, pip version will likely take precedence.
    pip3 install --no-cache-dir --no-deps --force-reinstall rich Pillow; \
    # Install TgCrypto, ignoring any pre-installed PyYAML
    pip3 install --no-cache-dir --ignore-installed PyYAML TgCrypto; \
    \
    # Install other Python dependencies from git and PyPI
    pip3 install --no-cache-dir ehforwarderbot python-telegram-bot pyqrcode; \
    pip3 install --no-cache-dir efb-mp-instantview-middleware; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-keyword-replace.git@324b96fece78de14f410a01f95a57e61b43c41d2; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-telegram-master.git@9e4f88e9a9f3621307d7337a6201f4b637fbafb2; \
    pip3 install --no-cache-dir git+https://github.com/0honus0/python-comwechatrobot-http.git@50e509f4ec3e11df7e4e5ab252a26ffef9a4470a; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-wechat-comwechat-slave.git@734bd5763a42e7563d6f004b2d1515f5fb773cdd; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb-keyword-reply.git@c7dfef513e85d6647ad78c70b4e3353ab8804977; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb_message_merge.git@946837e5508bf9325060f15f2a725525baf368ff;

# Stage 2: Final stage - Install only runtime dependencies and copy artifacts
FROM python:3.11-alpine

ENV LANG C.UTF-8
ENV TZ 'Asia/Shanghai'
ENV EFB_DATA_PATH /data/
ENV EFB_PARAMS ""
ENV EFB_PROFILE "default"
ENV HTTPS_PROXY ""

# Set timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone;

# Install runtime C-library dependencies including cron and necessary libs for python packages
RUN set -ex; \
    apk add --no-cache --update \
        libmagic \
        ffmpeg \
        zlib \
        jpeg \
        libffi \
        py3-pillow \
        zbar \
        openssl \
        libwebp \
        cronie \
        py3-ruamel.yaml; \
    # Clean up apk cache
    rm -rf /var/cache/apk/*;

# Explicitly tell the dynamic linker where to find shared libraries like libzbar.so
ENV LD_LIBRARY_PATH="/usr/lib:${LD_LIBRARY_PATH}"

# Copy installed python packages from builder stage's site-packages
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
# Copy executables installed by pip packages
COPY --from=builder /usr/local/bin/ehforwarderbot /usr/local/bin/ehforwarderbot

# Patch pyzbar to directly load the library from the known path in Alpine
# This avoids issues with find_library in minimal environments
RUN sed -i "s|path = find_library('zbar')|path = '/usr/lib/libzbar.so.0' # find_library('zbar')|" \
        /usr/local/lib/python3.11/site-packages/pyzbar/zbar_library.py

# Copy entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
