FROM ubuntu:24.04 AS base

# Variables for installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV XKB_DEFAULT_RULES=base

# Install dependencies and TurboVNC in a single layer.
# focal-security is enabled only to fetch libncursesw5 (no longer in 24.04); an apt
# preferences pin keeps every other package on the 24.04 (noble) suite to avoid
# accidental downgrades.
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main universe" > /etc/apt/sources.list.d/ubuntu-focal-sources.list && \
  printf 'Package: *\nPin: release n=focal-security\nPin-Priority: 100\n\nPackage: libncursesw5\nPin: release n=focal-security\nPin-Priority: 990\n' > /etc/apt/preferences.d/focal-security && \
  echo "tzdata tzdata/Areas select Europe" > ~/tx.txt && \
  echo "tzdata tzdata/Zones/Europe select Berlin" >> ~/tx.txt && \
  debconf-set-selections ~/tx.txt && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    apt-transport-https \
    bzip2 \
    fonts-dejavu-core \
    gnupg \
    gstreamer1.0-plugins-good \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-tools \
    libgl1 \
    libglu1-mesa \
    libglx-mesa0 \
    libgtk2.0-0 \
    libncursesw5 \
    libopenal1 \
    libsdl-image1.2 \
    libsdl-ttf2.0-0 \
    libsdl2-2.0 \
    libsndfile1 \
    libxv1 \
    nginx \
    novnc \
    pulseaudio \
    software-properties-common \
    supervisor \
    ucspi-tcp \
    unzip \
    websockify \
    wget \
    x11-utils \
    x11-xkb-utils \
    xauth \
    xfonts-base \
    xorg \
    xz-utils && \
  wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/TurboVNC.gpg && \
  wget -q -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends turbovnc && \
  rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

FROM base AS dosbox-base

# Dosbox-staging install (tarball)
ARG DOSBOX_STAGING_VERSION=0.82.2
RUN set -eux; \
    cd /tmp; \
    wget -O ds.tar.xz "https://github.com/dosbox-staging/dosbox-staging/releases/download/v${DOSBOX_STAGING_VERSION}/dosbox-staging-linux-x86_64-v${DOSBOX_STAGING_VERSION}.tar.xz"; \
    mkdir -p /opt/dosbox-staging; \
    tar -xJf ds.tar.xz -C /opt/dosbox-staging --strip-components=1; \
    install -m 0755 /opt/dosbox-staging/dosbox* /usr/local/bin/; \
    rm -f ds.tar.xz

# IDs configurable so host binds map cleanly
ARG DOSBOX_USER=dosbox
ENV DOSBOX_USER=${DOSBOX_USER}
ARG UID=1000
ARG GID=1000

RUN groupmod --new-name ${DOSBOX_USER} ubuntu && \
    usermod -d /home/dosbox -m -g ${DOSBOX_USER} -l ${DOSBOX_USER} ubuntu

# Per-user dirs + resources
RUN install -d -o ${DOSBOX_USER} -g ${DOSBOX_USER} \
      /home/${DOSBOX_USER}/.dosbox \
      /home/${DOSBOX_USER}/.config/dosbox \
      /home/${DOSBOX_USER}/dos

# GLSL shaders, etc.
RUN cp -r /opt/dosbox-staging/resources/* /home/${DOSBOX_USER}/.config/dosbox/ \
 && chown -R ${DOSBOX_USER}:${DOSBOX_USER} /home/${DOSBOX_USER} \
 && chmod -R g+s /home/${DOSBOX_USER}

# Main config lives in ~/.dosbox; staging reads ~/.config/dosbox/dosbox-staging.conf
#                     place your custom file at ~/.config/dosbox/dosbox.conf
COPY docker/dosbox.conf /home/${DOSBOX_USER}/.config/dosbox/dosbox-staging.conf
RUN echo "# Mount your custom configuration here" > /home/${DOSBOX_USER}/.config/dosbox/dosbox.conf && \
    printf '@echo off\necho Mount your custom AUTOEXEC.BAT here\n' > /home/${DOSBOX_USER}/dos/AUTOEXEC.BAT && \
    chown -R ${DOSBOX_USER}:${DOSBOX_USER} /home/${DOSBOX_USER}

RUN ln -s /home/${DOSBOX_USER}/dos /home/${DOSBOX_USER}/.config/dosbox/drives/c

FROM dosbox-base AS docksbox-base

# SECURITY: VNC runs with SecurityTypes=None (see docker/supervisord.conf), bound to
# 127.0.0.1 inside the container. Access is only via the nginx websockify proxy on
# port 80. Do not expose port 80 publicly without adding TLS + an external auth proxy.
RUN mkdir -p /root/.vnc

# Copy the files for audio and NGINX
COPY docker/default.pa docker/client.conf /etc/pulse/
COPY docker/nginx.conf /etc/nginx/
COPY docker/webaudio.js /usr/share/novnc/core/
COPY docker/xstartup.turbovnc /root/.vnc/xsession.sh
COPY docker/vnc-logs.sh /bin/vnc-logs

RUN chmod 0755 /root/.vnc/xsession.sh /bin/vnc-logs

# Inject code for audio in the NoVNC client
RUN sed -i "/import RFB/a \
  import WebAudio from '../core/webaudio.js'" \
  /usr/share/novnc/app/ui.js \
  && sed -i "/UI.rfb.resizeSession/a \
  var loc = window.location, new_uri; \
  if (loc.protocol === 'https:') { \
  new_uri = 'wss:'; \
  } else { \
  new_uri = 'ws:'; \
  } \
  new_uri += '//' + loc.host; \
  new_uri += '/audio'; \
  var wa = new WebAudio(new_uri); \
  document.addEventListener('keydown', e => { wa.start(); });" \
  /usr/share/novnc/app/ui.js

ENV SDL_VIDEODRIVER="x11"
ENV SDL_RENDER_DRIVER="software"
ENV LIBGL_ALWAYS_SOFTWARE="1"
ENV SDL_VIDEO_X11_VISUALID=0x022

EXPOSE 80
WORKDIR /home/${DOSBOX_USER}/dos

# Copy in supervisor configuration for startup
COPY docker/supervisord.conf /etc/supervisor/supervisord.conf
ENTRYPOINT [ "supervisord", "-c", "/etc/supervisor/supervisord.conf" ]

FROM docksbox-base AS docksbox

# Copy demo data
USER ${DOSBOX_USER}
COPY --chown=${DOSBOX_USER}:${DOSBOX_USER} keen /home/${DOSBOX_USER}/dos/KEEN
COPY --chown=${DOSBOX_USER}:${DOSBOX_USER} doom /home/${DOSBOX_USER}/dos/DOOM

# Run entrypoint as root
USER root
RUN chown -R ${DOSBOX_USER}:${DOSBOX_USER} /home/${DOSBOX_USER}
