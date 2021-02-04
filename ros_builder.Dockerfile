FROM ubuntu:bionic

# Configure container
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Generate Locale
RUN apt-get update && apt install -y curl gnupg2 lsb-release locales
RUN locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Add ROS apt repo
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'

RUN echo "1"

# Install rest of dev libs
RUN apt-get update
RUN apt-get install -y \
  build-essential \
  cmake \
  git \
  python3-colcon-common-extensions \
  python3-pip \
  python3-rosdep \
  python3-vcstool \
  wget

# Install some pip packages needed for testing
RUN python3 -m pip install -U \
  argcomplete \
  flake8 \
  flake8-blind-except \
  flake8-builtins \
  flake8-class-newline \
  flake8-comprehensions \
  flake8-deprecated \
  flake8-docstrings \
  flake8-import-order \
  flake8-quotes \
  pytest-repeat \
  pytest-rerunfailures \
  pytest \
  pytest-cov \
  pytest-runner \
  setuptools 

# Install Fast-RTPS dependencies
RUN apt install --no-install-recommends -y \
  libasio-dev \
  libtinyxml2-dev

# Install Cyclone DDS dependencies
RUN apt install --no-install-recommends -y \
  libcunit1-dev

# Create a build user and change to their directory
RUN useradd -ms /bin/bash build 
RUN usermod -aG sudo build
RUN echo "build:build" | chpasswd
WORKDIR /home/build
RUN chown -R build /home/build

# Pull down the ros2 source
RUN mkdir -p ./ros2_dashing/src 
WORKDIR ./ros2_dashing
RUN wget https://raw.githubusercontent.com/ros2/ros2/dashing/ros2.repos && vcs import src < ros2.repos

# Create the rosinstall
RUN rosdep init
RUN rosdep update
RUN rosdep install --from-paths src --ignore-src --rosdistro dashing -y --skip-keys "console_bridge fastcdr fastrtps libopensplice67 libopensplice69 rti-connext-dds-5.3.1 urdfdom_headers"

## Crossbuild
# Download Roborio toolchain
RUN curl -SL https://github.com/wpilibsuite/roborio-toolchain/releases/download/v2021-2/FRC-2021-Linux-Toolchain-7.3.0.tar.gz | sh -c 'mkdir -p /usr/local && cd /usr/local && tar xzf - --strip-components=2'

RUN sudo apt-get install -y libtinyxml2-dev

ENV USER_HOME=/home/build
COPY ./docker/* $USER_HOME


# Start the colcon build
# RUN colcon build --symlink-install
RUN colcon build --merge-install \
    # --cmake-force-configure \
    --cmake-args -DBUILD_TESTING=NO \
    -DCMAKE_TOOLCHAIN_FILE="$USER_HOME/rostoolchain.cmake" \
    -DCMAKE_INSTALL_PREFIX="usr/local/arm-frc2021-linux-gnueabi /opt/ros/dashing" \
    # -DCMAKE_BUILD_TYPE=Release