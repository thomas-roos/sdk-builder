# LCM SDK builder

[[_TOC_]]

## Introduction

The LCM SDK Builder is designed to offer a systematic approach to rebuild the prpl LCM SDK via a Dockerfile in a customizable manner, resulting in a final container equipped with a preinstalled/ready-to-use Yocto eSDK. Various arguments are available to facilitate the rebuilding of the SDK for specific targets (supported targets: `container-cortexa53` and `container-x86-64`) through the `LCM_TARGET_MACHINE` option. 
Additionally, other options are provided to configure the IP of the sstate cached server (if available) and the versions of the meta layers used in the SDK construction. Below is the list of options along with their default values:

    * LCM_TARGET_MACHINE="container-cortexa53"
    * SSTATE_CACHE_IP="172.17.0.1"
    * AMX_VERSION="honister_v11.23.3"
    * USP_VERSION="honister_v3.6.1"
    * CONTAINERS_VERSION="honister_v1.2.2"
    * YOCTO_VERSION="honister"

## Building the SDK

Currently, no automated CI job has been established to build the container automatically. Therefore, the container must be built manually using the provided Dockerfile and resources. The build command is as follows:

```
docker build -t lcm_sdk --build-arg ARG1=value1 --build-arg ARG2=value2  .
```

## Running the SDK and building LCM compatible containers. 

To run the SDK, follow these steps:

```
docker run -it --name lcm_sdk lcm_sdk
```

Once the SDK container is started, it possible to build the default LCM container using the follwing command:

```
root@51768c26732d:/sdkworkdir#  devtool build-image
```

For further details on utilizing the SDK, refer to the documentation provided here: https://prplfoundationcloud.atlassian.net/wiki/spaces/LCM/pages/194936927/LCM+SDK+-+Introduction+and+howto