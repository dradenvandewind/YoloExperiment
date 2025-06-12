FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# Env vars
#ENV PYTHONPATH=/usr/local/lib/python3.8/site-packages:/usr/local/lib/python3.10/site-packages:/usr/local/lib/python3.11/site-packages:/usr/lib/python3.10

ENV GI_TYPELIB_PATH=/usr/local/lib/x86_64-linux-gnu/girepository-1.0:/usr/lib/x86_64-linux-gnu/girepository-1.0
ENV GST_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/gstreamer-1.0/
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV DISPLAY=:1
ENV GST_DEBUG=2
ENV GST_DEBUG_DUMP_DOT_DIR=/tmp
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64/
ENV TF_FORCE_GPU_ALLOW_GROWTH=true
ENV TF_ENABLE_GPU_GARBAGE_COLLECTION=false
ENV PREFIX=/usr
ENV TAG=1.26.2
#1.20.4
#1.26.2
ENV TZ=Europe/Paris

# Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Installer les outils nécessaires pour gérer les dépôts
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common

RUN sed -i 's/^# deb/deb/g' /etc/apt/sources.list && \
    apt-get update

RUN apt-get update && apt-get install -y --no-install-recommends  unzip git flex bison \
    gobject-introspection \
    libgirepository1.0-dev \
    vim \
    nano \
    net-tools \
    tcpdump \
    alsa-utils \
    lshw \
    graphviz \
    syslog-ng \
    openssh-client \
    python3-dev \
    libpython3-dev \
    python3-pip \
    python3-setuptools \
    python3-distutils \
    python3 python3-dev python3-pip python3-setuptools python3-distutils \
    build-essential meson ninja-build git \
    libglib2.0-dev libgirepository1.0-dev gobject-introspection \
    libffi-dev libtool pkg-config curl wget

# Installer distutils si absent
#RUN apt update && apt install -y python3-distutils

# ⚠️ Corriger manuellement si le fichier distutils est encore manquant
RUN if [ ! -f /usr/lib/python3.10/distutils/__init__.py ]; then \
      mkdir -p /usr/lib/python3.10/distutils && \
      cp -r /usr/lib/python3/dist-packages/distutils/* /usr/lib/python3.10/distutils/; \
    fi

RUN python3 -c "from distutils.msvccompiler import MSVCCompiler"

# Force create /usr/lib/python3.10/distutils and patch missing file
RUN mkdir -p /usr/lib/python3.10/distutils && \
    curl -sSfL -o /usr/lib/python3.10/distutils/msvccompiler.py \
        https://raw.githubusercontent.com/python/cpython/3.10/Lib/distutils/msvccompiler.py && \
    curl -sSfL -o /usr/lib/python3.10/distutils/__init__.py \
        https://raw.githubusercontent.com/python/cpython/3.10/Lib/distutils/__init__.py


# Install Python tools
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Required for GStreamer build
RUN pip3 install --no-cache-dir meson==1.4.1 scikit-build ninja opencv-python 

# Fix library paths
RUN echo "/usr/local/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf && \
    echo "/usr/local/lib/x86_64-linux-gnu/gstreamer-1.0" >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf && \
    echo "/usr/lib/x86_64-linux-gnu/gstreamer-1.0" >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf && \
    echo "/usr/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf && \
    ldconfig

# Workdir for build
WORKDIR /root

# Install NVIDIA Video Codec SDK
COPY ./Video_Codec_SDK_11.0.10.zip .
RUN unzip Video_Codec_SDK_11.0.10.zip && \
    cp Video_Codec_SDK_11.0.10/Interface/* /usr/local/include/ && \
    cp Video_Codec_SDK_11.0.10/Lib/linux/stubs/x86_64/libnv* /usr/lib/x86_64-linux-gnu/ && \
    rm -rf Video_Codec_SDK_11.0.10.zip Video_Codec_SDK_11.0.10
# add quick for build it  
RUN pip install "setuptools<65"
RUN apt-get install -y libc6-dev 
RUN git clone https://gitlab.freedesktop.org/gstreamer/gstreamer.git && \
  cd gstreamer && \
  git checkout tags/$TAG && \
  mkdir build && cd build && \
  meson setup ..            \
       --prefix=/usr       \
       --buildtype=release && \
    ninja && \
    ninja install && \
    ldconfig 
    #&& \
    #cd .. && \
    #rm -rf gstreamer


# Build GStreamer core  



# Copy application
#COPY ./gstreamer_plugin.py /home/gstreamer_plugin.py

# Set working directory
WORKDIR /home/workingsrc
RUN apt-get update && apt-get install -y --no-install-recommends libsoup2.4-dev libsoup-3.0-dev libjack-jackd2-dev jackd2
 

# Arguments pour correspondre à l'utilisateur host
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=user

# Créer l'utilisateur avec les mêmes IDs que le host
RUN groupadd -g $GROUP_ID $USERNAME && \
    useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USERNAME

# Ajouter aux groupes vidéo et audio
RUN usermod -aG video,audio $USERNAME
# get render id with this command line on host :getent group render
RUN groupadd -g 109 render



USER $USERNAME

# 
# gst-launch-1.0 videotestsrc ! videoconvert ! xvimagesink




# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD gst-inspect-1.0 --version || exit 1

EXPOSE 9012

CMD ["/bin/bash"]
