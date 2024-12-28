FROM ubuntu:22.04 as yocto_base

ARG SYS_USER="lcmuser"
ARG YOCTO_WORKSPACE="/home/${SYS_USER}/yoctoworkdir"
# Default target image: image-lcm-container-minimal. Thread image is named image-thread
ARG IMAGE_CONTAINER="image-lcm-container-minimal"

# Configurable options
# Set default sstate cache IP address (running in docker container on the same machine)
ARG SSTATE_CACHE_IP="172.17.0.1"
## Set default version for the different meta layers
ARG AMX_VERSION="gen_honister_v15.16.0"
ARG USP_VERSION="honister_v4.2.0"
ARG CONTAINERS_VERSION="honister_v1.3.2"
ARG THREAD_VERSION="honister_v0.0.4"
ARG YOCTO_VERSION="honister" 
# Default target machine: container-x86-64, could be replaced by container-cortexa53
ARG LCM_TARGET_MACHINE="container-x86-64"

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

## Install packages needed for retriving/building SDK
## Install additional tools required for deploying, sstate cache ...
## Set configuration ..
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y python3.9 chrpath cpio cpp diffstat g++ gawk gcc git locales make patch texinfo git-lfs tree zlib1g zstd liblz4-tool python3-distutils python3-pip screen quilt wget vim git-all fakeroot rsync skopeo sshpass sudo && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8
###

## Create user and working dirs
RUN useradd -ms /bin/bash ${SYS_USER}
USER ${SYS_USER}
RUN mkdir ${YOCTO_WORKSPACE}
WORKDIR ${YOCTO_WORKSPACE}
###

## Clone yocto honister
RUN git clone -b ${YOCTO_VERSION} https://git.yoctoproject.org/poky ${YOCTO_WORKSPACE}/poky
WORKDIR ${YOCTO_WORKSPACE}/poky
RUN source oe-init-build-env ${YOCTO_WORKSPACE}/builddir
###

## Copy configuration samples and adapt them
COPY resources/conf/* ${YOCTO_WORKSPACE}/builddir/conf/
RUN sed -i "s/LCM_TARGET_MACHINE/${LCM_TARGET_MACHINE}/g" ${YOCTO_WORKSPACE}/builddir/conf/local.conf; \
    sed -i "s/SERVER_SSTATE_IP/${SSTATE_CACHE_IP}/g" ${YOCTO_WORKSPACE}/builddir/conf/sstatecache.conf
###

## Prepare the work directory
RUN mkdir -p ${YOCTO_WORKSPACE}/meta-lcm
WORKDIR ${YOCTO_WORKSPACE}/meta-lcm
###

## Retrieve all required meta layers: 
## * common meta layers 
## * SoftAtHome yocto meta layers (Ambiorix, USP and meta-containers reponsible for handling OCI containers)
RUN git clone -b ${YOCTO_VERSION} https://github.com/openembedded/meta-openembedded.git ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded && \
git clone -b ${YOCTO_VERSION} https://github.com/lgirdk/meta-virtualization.git ${YOCTO_WORKSPACE}/meta-lcm/meta-virtualization && \
git clone -b ${CONTAINERS_VERSION} https://gitlab.com/soft.at.home/buildsystems/yocto/meta-containers.git ${YOCTO_WORKSPACE}/meta-lcm/meta-containers && \
git clone -b ${USP_VERSION} https://gitlab.com/soft.at.home/buildsystems/yocto/meta-usp.git ${YOCTO_WORKSPACE}/meta-lcm/meta-usp && \
git clone -b ${AMX_VERSION} https://gitlab.com/soft.at.home/buildsystems/yocto/meta-amx.git ${YOCTO_WORKSPACE}/meta-lcm/meta-amx && \
git clone -b ${THREAD_VERSION} https://gitlab.com/soft.at.home/buildsystems/yocto/meta-thread.git ${YOCTO_WORKSPACE}/meta-lcm/meta-thread
###


## Add all retrieved meta layers to yocto build env
WORKDIR ${YOCTO_WORKSPACE}/poky
RUN source oe-init-build-env ${YOCTO_WORKSPACE}/builddir && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded/meta-oe/ && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded/meta-python/ && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded/meta-networking/ && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded/meta-filesystems/ && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-openembedded/meta-webserver/  && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-virtualization && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-amx && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-usp && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-containers && \
bitbake-layers add-layer ${YOCTO_WORKSPACE}/meta-lcm/meta-thread/
###

## - Build target image. 
## - Push to sstate cache server. pushing to sstate server is allowed to fail (in case no sstate is configured).
## - Generate esdk installer.
## - Copy output installer
RUN source oe-init-build-env ${YOCTO_WORKSPACE}/builddir && \
    bitbake ${IMAGE_CONTAINER} && \
    rsync -ruq --no-links --progress -e "sshpass -p 'mycacheserverpassword' ssh -p 5555 -o StrictHostKeyChecking=no" ${YOCTO_WORKSPACE}/builddir/sstate-cache/* root@${SSTATE_CACHE_IP}:/srv/sstate-cache/ || true; \
    bitbake ${IMAGE_CONTAINER} -c populate_sdk_ext; \
    cp ${YOCTO_WORKSPACE}/builddir/tmp-glibc/deploy/sdk/meta-containers*.sh /tmp/esdk_installer.sh



FROM ubuntu:22.04

## Set docker container information
LABEL org.opencontainers.image.ref.name="lcm_sdk_x86-64" \
	org.opencontainers.image.version="v3.2-beta" \
	version="v3.2-beta"

ARG SYS_USER="lcmuser"
ARG YOCTO_WORKSPACE="/home/${SYS_USER}/yoctoworkdir"
ARG SDK_WORKSPACE="/sdkworkdir"

# Configurable options
# Set default sstate cache IP address (running in docker container on the same machine)
ARG SSTATE_CACHE_IP="172.17.0.1"

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

## Install packages needed for retriving/building SDK
## Install additional tools required for deploying, sstate cache ...
## Set configuration ..
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y python3.9 chrpath cpio cpp diffstat g++ gawk gcc git locales make patch texinfo git-lfs tree zlib1g zstd liblz4-tool python3-distutils python3-pip screen quilt wget vim git-all fakeroot rsync skopeo sshpass && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8
###

## Create user and working dirs
RUN useradd -ms /bin/bash ${SYS_USER}; \
    mkdir ${SDK_WORKSPACE}; \
    chown -R ${SYS_USER}:${SYS_USER} ${SDK_WORKSPACE}
USER ${SYS_USER}
ENV SYS_USER=${SYS_USER}
###

## If SDK build env required, The following will be done:
## - Run esdk installer to specific location.
## - Cleanup workspace which is not required anymore.
## - Remove cache
## - Configure the entrypoint
## Build target image

RUN mkdir -p /tmp/sdk
COPY --from=yocto_base /tmp/esdk_installer.sh /tmp/

RUN /tmp/esdk_installer.sh -y -n -d ${SDK_WORKSPACE} \
    rm -rf ${SDK_WORKSPACE}/cache/*; rm -rf ${SDK_WORKSPACE}/sstate-cache/*; \
    WORKDIR ${SDK_WORKSPACE}; \
    ENV SDK_WORKSPACE=${SDK_WORKSPACE}; \
    echo "cd ${SDK_WORKSPACE} && source ${SDK_WORKSPACE}/layers/poky/oe-init-build-env ." >> /home/${SYS_USER}/.bashrc;

CMD ["/bin/bash"]
