# This Dockerfile is used to build an headles vnc image based on Ubuntu

FROM ubuntu:xenial-20210416

ENV REFRESHED_AT 2018-10-29

LABEL io.k8s.description="Headless VNC Container with Xfce window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Ubuntu" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, ubuntu, xfce" \
      io.openshift.non-scalable=true

## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/home/ubuntu \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/home/ubuntu/install \
    NO_VNC_HOME=/home/ubuntu/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW="" \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD ./src/common/xfce/ $HOME/

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

USER 1000

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]

# Switch to root user to install additional software
USER 0

# Utilities
RUN apt-get update && \
    apt-get -y install apt-transport-https unzip curl usbutils software-properties-common libc6 libstdc++6 zlib1g libncurses5 build-essential libssl-dev ruby ruby-dev sudo xz-utils --no-install-recommends && \
    rm -r /var/lib/apt/lists/*

RUN groupadd --gid 1000 ubuntu && \
  useradd --uid 1000 --gid ubuntu --shell /bin/bash --create-home ubuntu && \
  adduser ubuntu sudo && \
  adduser ubuntu root && \
  (echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers)

# jdk8
# https://github.com/carlos3g/my-linux-workspace/blob/d29a68ef7c/ubuntu/workspace.sh
RUN apt-get update && \
    add-apt-repository ppa:openjdk-r/ppa && \
    apt-get -y update && \
    apt-get -y install openjdk-8-jdk && \
    rm -r /var/lib/apt/lists/*

# FROM export JAVA_HOME=$(update-alternatives --query javac | sed -n -e 's/Best: *\(.*\)\/bin\/javac/\1/p')
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Android build requirements
RUN gem install bundler

##############################

ENV NODE_VERSION 13.12.0

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && mkdir -p /usr/local/bin \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  # smoke tests
  && node --version \
  && npm --version

ENV YARN_VERSION 1.22.4

RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  # smoke test
  && yarn --version

###############################
# https://hub.docker.com/r/chibatching/docker-android-sdk/dockerfile

## switch back to default user
USER ubuntu

# Download and untar Android SDK tools
RUN sudo mkdir -p /usr/local/android-sdk-linux && \
    sudo chown ubuntu:ubuntu /usr/local/android-sdk-linux && \
    wget https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O tools.zip && \
    unzip tools.zip -d /usr/local/android-sdk-linux && \
    rm tools.zip

# Set environment variable
ENV ANDROID_HOME=/usr/local/android-sdk-linux
ENV ANDROID_SDK_ROOT=/usr/local/android-sdk-linux

# important to do that in separate ENV
ENV PATH=$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Make license agreement
RUN mkdir $ANDROID_HOME/licenses && \
    echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > $ANDROID_HOME/licenses/android-sdk-license && \
    echo d56f5187479451eabf01fb78af6dfcb131a6481e >> $ANDROID_HOME/licenses/android-sdk-license && \
    echo 24333f8a63b6825ea9c5514f83c2829b004d1fee >> $ANDROID_HOME/licenses/android-sdk-license && \
    echo 84831b9409646a918e30573bab4c9c91346d8abd > $ANDROID_HOME/licenses/android-sdk-preview-license

RUN sudo mkdir /app  && \
    sudo chown ubuntu:ubuntu /app

ENV PATH=/home/ubuntu/.npm-global/bin:$PATH \
    NPM_CONFIG_PREFIX=/home/ubuntu/.npm-global

RUN curl --location https://redirector.gvt1.com/edgedl/android/studio/ide-zips/3.6.2.0/android-studio-ide-192.6308749-linux.tar.gz -o /home/ubuntu/android-studio-ide-192.6308749-linux.tar.gz && \
    tar xvzf /home/ubuntu/android-studio-ide-192.6308749-linux.tar.gz -C /home/ubuntu && \
    rm -f /home/ubuntu/android-studio-ide-192.6308749-linux.tar.gz

ENV PATH=/home/ubuntu/android-studio/bin:$PATH

# Update and install using sdkmanager
# from
# $ANDROID_HOME/tools/bin/sdkmanager --list

RUN echo "y" | $ANDROID_HOME/tools/bin/sdkmanager \
  "build-tools;30.0.1" \
  "build-tools;29.0.3" \
  "cmdline-tools;latest" \
  "emulator" \
  "extras;android;m2repository" \
  "extras;google;m2repository" \
  "patcher;v4" \
  "platform-tools" \
  "platforms;android-30" \
  "platforms;android-28" \
  "sources;android-29" \
  "system-images;android-30;google_apis;x86" \
  "tools"

RUN echo "no" | $ANDROID_HOME/tools/bin/avdmanager create avd --device "Nexus 6" --name "Nexus_6" --package "system-images;android-30;google_apis;x86"
# $ANDROID_HOME/emulator/emulator-headless @pixel -no-boot-anim -netdelay none -no-snapshot -wipe-data -verbose -show-kernel -no-audio -gpu swiftshader_indirect -no-snapshot &> /tmp/log.txt &

# ENV ANDROID_STUDIO_HOME /home/ubuntu/android-studio

# # Install extra Android SDK
# ENV ANDROID_SDK_EXTRA_COMPONENTS extra-google-google_play_services,extra-google-m2repository,extra-android-m2repository,source-21,addon-google_apis-google-21,sys-img-x86-addon-google_apis-google-21
# RUN echo y | ${ANDROID_HOME}/tools/android update sdk --no-ui --all --filter "${ANDROID_SDK_EXTRA_COMPONENTS}"


ENV GRADLE_HOME /opt/gradle
ENV GRADLE_VERSION 4.7

ARG GRADLE_DOWNLOAD_SHA256=fca5087dc8b50c64655c000989635664a73b11b9bd3703c7d6cabd31b7dcdb04
RUN set -o errexit -o nounset \
  && echo "Downloading Gradle" \
  && wget --no-verbose --output-document=gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
  \
  && echo "Checking download hash" \
  && echo "${GRADLE_DOWNLOAD_SHA256} *gradle.zip" | sha256sum --check - \
  \
  && echo "Installing Gradle" \
  && unzip gradle.zip \
  && rm gradle.zip \
  && sudo mv "gradle-${GRADLE_VERSION}" "${GRADLE_HOME}/" \
  && sudo ln --symbolic "${GRADLE_HOME}/bin/gradle" /usr/bin/gradle \
  \
  && mkdir /home/ubuntu/.gradle \
  && sudo chown --recursive ubuntu:ubuntu /home/ubuntu \
  \
  && echo "Symlinking root Gradle cache to gradle Gradle cache" \
  && sudo ln -s /home/ubuntu/.gradle /root/.gradle

USER 0

RUN add-apt-repository -y ppa:git-core/ppa && apt -y update && apt-get -y upgrade && apt-get -y update && apt autoremove -y && apt-get clean && apt-get install -y libc6 git

RUN apt-get update && apt-get install build-essential -y && apt install -y glibc-source

RUN add-apt-repository -y ppa:git-core/ppa && apt -y update && apt-get -y upgrade && apt-get -y update && apt autoremove -y && apt-get clean

RUN apt install -y haskell-stack

USER ubuntu

RUN npm install -g cordova
# RUN npm install -g spago purescript

ENV PATH=$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$PATH

RUN sudo apt-get update && \
    sudo apt-get install -y gconf2 gconf-service libappindicator1 libdbusmenu-glib4 libdbusmenu-gtk4 libindicator7 && \
    curl --location https://sk-autoupdates.nativescript.cloud/v1/update/official/linux/NativeScriptSidekick-amd64.deb -o /home/ubuntu/NativeScriptSidekick-amd64.deb && \
    sudo dpkg -i /home/ubuntu/NativeScriptSidekick-amd64.deb

# NativeScript
RUN mkdir -p /home/ubuntu/.npm-global && \
    npm cache verify && \
    npm cache clean --force && \
    npm install -g nativescript

# cd /app/blank/blank/
# RUN tns platform update android
    # tns error-reporting disable

# https://docs.nativescript.org/sidekick/intro/installation
# to open sidekick: top navbar -> applications -> development -> sidekick OR open with ....

# cd /app
# cordova run android
# cordova run -- --livereload
# cordova build -- --webpackConfig webpack.config.js

# ns doctor android
# cd /app && ns create drawernavigationjs --template @nativescript/template-drawer-navigation

# ADD ./src/Studio.deb /tmp/Studio.deb

# RUN sudo apt-get clean && \
#  sudo apt update && \
#  sudo apt-get -f install && \
#  sudo dpkg --configure -a && \
#  sudo apt-get -f -y install && \
#  sudo apt-get -u -y dist-upgrade && \
#  sudo apt-get clean && \
#  sudo apt update && \
#  sudo apt-get -f install && \
#  sudo dpkg --configure -a && \
#  sudo apt-get -f -y install && \
#  sudo apt-get -u -y dist-upgrade && \
#  sudo apt install -y \
#  libgstreamer1.0-dev \
#  libgstreamer-plugins-base1.0-dev \
#  libgstreamer-plugins-good1.0-dev \
#  libglib2.0-dev \
#  libgl1-mesa-dev \
#  libglu1-mesa-dev \
#  libsm-dev \
#  libx11-dev \
#  libx11-xcb-dev \
#  libexpat-dev \
#  libxkbcommon-dev \
#  libxcb1-dev \
#  libxcb-glx0-dev \
#  libxcb-icccm4-dev \
#  libxcb-image0-dev \
#  libxcb-keysyms1-dev \
#  libxcb-randr0-dev \
#  libxcb-render0-dev \
#  libxcb-render-util0-dev \
#  libxcb-shape0-dev \
#  libxcb-shm0-dev \
#  libxcb-sync-dev \
#  libxcb-xfixes0-dev \
#  libxcb-xinerama0-dev \
#  libxcb-xkb-dev \
#  libxcb-util-dev \
#  libexpat1 \
#  libgstreamer1.0-0 \
#  libgstreamer-plugins-base1.0-0 \
#  libgstreamer-plugins-good1.0-0 \
#  libgstreamer-plugins-bad1.0-0 \
#  gstreamer1.0-libav \
#  libglib2.0-0 \
#  libxkbcommon0 \
#  libxcb1 \
#  libxcb-glx0 \
#  libxcb-randr0 \
#  libxcb-render0 \
#  libxcb-shape0 \
#  libxcb-shm0 \
#  libxcb-sync1 \
#  libxcb-xfixes0 \
#  libxcb-xinerama0 \
#  libxcb-xkb1 && \
#  sudo apt-get clean && \
#  sudo apt update && \
#  sudo apt-get -f install && \
#  sudo dpkg --configure -a && \
#  sudo apt-get -f -y install && \
#  sudo apt-get -u -y dist-upgrade && \
#  sudo apt install /tmp/Studio.deb && rm -f /tmp/Studio.deb

# # gstreamer1.0-gl \
