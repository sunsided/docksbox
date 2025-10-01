FROM ubuntu:22.04 AS base

# Variables for installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV XKB_DEFAULT_RULES=base

# Install dependencies
RUN apt-get update && \
  echo "tzdata tzdata/Areas select Europe" > ~/tx.txt && \
  echo "tzdata tzdata/Zones/Europe select Berlin" >> ~/tx.txt && \
  debconf-set-selections ~/tx.txt && \
  apt-get install -y fluxbox xfonts-base unzip gnupg apt-transport-https wget software-properties-common novnc websockify libxv1 libglu1-mesa xauth x11-utils xorg libegl1-mesa xauth x11-xkb-utils software-properties-common bzip2 gstreamer1.0-plugins-good gstreamer1.0-pulseaudio gstreamer1.0-tools libglu1-mesa libgtk2.0-0 libncursesw5 libopenal1 libsdl-image1.2 libsdl-ttf2.0-0 libsdl2-2.0 libsndfile1 nginx pulseaudio supervisor ucspi-tcp wget build-essential ccache

# Install VNC server
RUN wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | gpg --dearmor > /etc/apt/trusted.gpg.d/TurboVNC.gpg && \
  wget -q -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list && \
  apt-get update && \
  apt-get install -y turbovnc

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

RUN mkdir ~/.vnc && \
  mkdir -p ~/.dosbox ~/.config/dosbox
RUN cp -r /opt/dosbox-staging/resources/glshaders /root/.config/dosbox/

COPY docker/dosbox.conf /root/.dosbox/dosbox.conf

# Symlink dosbox config for dosbox-staging
RUN mkdir -p /root/.config/dosbox && \
    ln -sf /root/.dosbox/dosbox.conf /root/.config/dosbox/dosbox-staging.conf

FROM dosbox-base AS docksbox

# User Settings for VNC
ENV USER=root
ENV PASSWORD=password1

# Set VNC password
RUN mkdir -p /root/.vnc
RUN printf '%s\n' "$PASSWORD" "$PASSWORD" | /opt/TurboVNC/bin/vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Copy the files for audio and NGINX
COPY docker/default.pa docker/client.conf /etc/pulse/
COPY docker/nginx.conf /etc/nginx/
COPY docker/webaudio.js /usr/share/novnc/core/
COPY docker/xstartup.turbovnc /root/.vnc/xsession.sh
COPY docker/vnc-logs.sh /bin/vnc-logs

# SECURITY: This is a local environment only - do not use in production
RUN chmod 0777 /root/.vnc/xsession.sh
RUN chmod 0777 /bin/vnc-logs

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

# RUN echo $PASSWORD | vncpasswd -f > ~/.vnc/passwd && \
#   chmod 0600 ~/.vnc/passwd

COPY keen /dos/keen
COPY doom /dos/doom

EXPOSE 80

ENV SDL_VIDEODRIVER="x11"
ENV SDL_RENDER_DRIVER="software"
ENV LIBGL_ALWAYS_SOFTWARE="1"

# Copy in supervisor configuration for startup
COPY docker/supervisord.conf /etc/supervisor/supervisord.conf
ENTRYPOINT [ "supervisord", "-c", "/etc/supervisor/supervisord.conf" ]
