# Stage 1: Builder stage - Install build dependencies and Python packages
FROM python:3.11-alpine AS builder

ARG EFB_TELEGRAM_MASTER_REF=533b53c8e627f88fe5196b9828b08f463312d0db
ARG PYTHON_COMWECHATROBOT_HTTP_REF=f8d2f0b63a6292aae332b12fdd4992d24be92182
ARG EFB_WECHAT_COMWECHAT_SLAVE_REF=347c772749b4c6c600b22f24aa093ea6e5e8672f
ARG EFB_MAP_MIDDLEWARE_REF=51f360e95bd38db4bd65485f1bdb5a388e6f5be9

ENV LANG=C.UTF-8 \
    TZ='Asia/Shanghai' \
    PIP_NO_CACHE_DIR=1 \
    PIP_NO_COMPILE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

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
        libwebp-dev;
    # Install python packages using pip with --no-cache-dir
RUN pip3 install --no-cache-dir urllib3==1.26.15; \
    pip3 install --no-cache-dir --upgrade 'setuptools>=82.0.1'; \
    # Install Pillow from pip (the runtime uses it for Telegram media).
    # Note: Pillow might be installed via apk (py3-pillow) and pip, pip version will likely take precedence.
    pip3 install --no-cache-dir --no-deps --force-reinstall Pillow; \
    # Ensure PyYAML is available.
    pip3 install --no-cache-dir --ignore-installed PyYAML;

    # Install other Python dependencies from git and PyPI
RUN pip3 install --no-cache-dir ehforwarderbot python-telegram-bot; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-mp-instantview-middleware.git@e7772cc2c5acc5b776f4bc0bc7562ea5b893eab9; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-map-middleware.git@${EFB_MAP_MIDDLEWARE_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-keyword-replace.git@ede3f2ede8092017d7005f9b2150d6325076c852; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-telegram-master.git@${EFB_TELEGRAM_MASTER_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/python-comwechatrobot-http.git@${PYTHON_COMWECHATROBOT_HTTP_REF}; \
    pip3 install --no-cache-dir git+https://github.com/jiz4oh/efb-wechat-comwechat-slave.git@${EFB_WECHAT_COMWECHAT_SLAVE_REF}; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb-keyword-reply.git@c7dfef513e85d6647ad78c70b4e3353ab8804977; \
    pip3 install --no-cache-dir git+https://github.com/QQ-War/efb_message_merge.git@946837e5508bf9325060f15f2a725525baf368ff;

# Keep build-only bytecode and packaging tools out of the copied runtime tree.
RUN find /usr/local/lib/python3.11/site-packages -type f \
        \( -name '*.pyc' -o -name '*.pyo' \) -delete \
    && rm -rf \
        /usr/local/lib/python3.11/site-packages/pip \
        /usr/local/lib/python3.11/site-packages/pip-*.dist-info \
        /usr/local/lib/python3.11/site-packages/wheel \
        /usr/local/lib/python3.11/site-packages/wheel-*.dist-info

# Stage 2: Final stage - Install only runtime dependencies and copy artifacts
FROM python:3.11-alpine

ENV LANG=C.UTF-8 \
    TZ='Asia/Shanghai' \
    EFB_DATA_PATH=/data/ \
    EFB_PARAMS="" \
    EFB_PROFILE="default" \
    HTTPS_PROXY="" \
    PIP_NO_CACHE_DIR=1 \
    PIP_NO_COMPILE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

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
        openssl \
        sqlcipher-libs \
        libwebp; \
    # Clean up apk cache
    rm -rf /var/cache/apk/*;

# Remove the base image's packaging tools before copying the single builder
# version of setuptools and the application packages.
RUN rm -rf \
        /usr/local/lib/python3.11/site-packages/pip \
        /usr/local/lib/python3.11/site-packages/pip-*.dist-info \
        /usr/local/lib/python3.11/site-packages/setuptools \
        /usr/local/lib/python3.11/site-packages/setuptools-*.dist-info \
        /usr/local/lib/python3.11/site-packages/wheel \
        /usr/local/lib/python3.11/site-packages/wheel-*.dist-info \
        /usr/local/bin/pip \
        /usr/local/bin/pip3 \
        /usr/local/bin/pip3.11

# Copy installed python packages from builder stage's site-packages
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
# Copy executables installed by pip packages
COPY --from=builder /usr/local/bin/ehforwarderbot /usr/local/bin/ehforwarderbot

# Copy entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
