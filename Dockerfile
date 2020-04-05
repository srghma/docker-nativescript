FROM consol/ubuntu-xfce-vnc
MAINTAINER Kristoph Junge <kristoph.junge@gmail.com>

# Switch to root user to install additional software
USER 0

# Utilities
RUN apt-get update && \
    apt-get -y install apt-transport-https unzip curl usbutils --no-install-recommends && \
    rm -r /var/lib/apt/lists/*

# JAVA
RUN apt-get update && \
    apt-get -y install default-jdk --no-install-recommends && \
    rm -r /var/lib/apt/lists/*

# NodeJS
# From https://github.com/nodejs/docker-node/blob/master/13/stretch/Dockerfile
##############################
# nodejs
RUN curl -sL https://deb.nodesource.com/setup_13.x | bash - \
    && apt-get install -y nodejs

##############################

# Android build requirements
RUN apt-get update && \
    apt-get -y install lib32stdc++6 lib32z1 --no-install-recommends && \
    rm -r /var/lib/apt/lists/*

# Android SDK
ARG ANDROID_SDK_URL="https://dl.google.com/android/repository/tools_r25.2.5-linux.zip"
ARG ANDROID_SYSTEM_PACKAGE="android-25"
ARG ANDROID_BUILD_TOOLS_PACKAGE="build-tools-25.0.2"
ARG ANDROID_PACKAGES="platform-tools,$ANDROID_SYSTEM_PACKAGE,$ANDROID_BUILD_TOOLS_PACKAGE,extra-android-m2repository,extra-google-m2repository"
RUN curl $ANDROID_SDK_URL -o /tmp/android-sdk.zip -L -J
RUN mkdir /opt/android-sdk /app /dist && \
    chown 1000:1000 /tmp/android-sdk.zip /opt/android-sdk /app /dist /usr/lib/node_modules

# NativeScript
RUN npm install -g nativescript && \
    tns error-reporting disable

ENV ANDROID_HOME /opt/android-sdk
ENV PATH $PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
RUN tns error-reporting disable && \
    unzip -q /tmp/android-sdk.zip -d /opt/android-sdk && \
    rm /tmp/android-sdk.zip && \
    echo "y" | /opt/android-sdk/tools/android --silent update sdk -a -u -t $ANDROID_PACKAGES
# Self-update of 'tools' package is currently not working?
#RUN echo "y" | /opt/android-sdk/tools/android --silent update sdk -a -u -t tools

## switch back to default user
USER 1000

VOLUME ["/app","/dist"]
