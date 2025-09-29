################################
# Container to be used with bootc-image-builder
# See https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/
################################

# Base image for bootc
FROM quay.io/fedora/fedora-bootc:42

################################
# Packages: installation
################################
#=================================
# cloud-init to fetch SSH keys and users from cloud provider metadata
#=================================
RUN dnf install -y cloud-init \ 
      && \
      ln -s ../cloud-init.target /usr/lib/systemd/system/default.target.wants

#=================================
# NVIDIA Cuda drivers
# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html#fedora-installation-network
#=================================
COPY <<EOF /etc/yum.repos.d/nvidia-cuda.repo
[nvidia-cuda]
name=nvidia-container-toolkit
baseurl=https://developer.download.nvidia.com/compute/cuda/repos/fedora42/x86_64/
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://developer.download.nvidia.com/compute/cuda/repos/fedora42/x86_64/D42D0685.pub
EOF
RUN <<EOF
dnf -y install nvidia-driver-cuda kmod-nvidia-latest-dkms
EOF

#=================================
# NVIDIA Container Toolkit
# See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
#=================================

# Add YUM repository for NVIDIA Container Toolkit
COPY <<EOF /etc/yum.repos.d/nvidia-container-toolkit.repo
[nvidia-container-toolkit]
name=nvidia-container-toolkit
baseurl=https://nvidia.github.io/libnvidia-container/stable/rpm/x86_64
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://nvidia.github.io/libnvidia-container/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

ARG NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
RUN dnf install -y \
      nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION}

#=================================
# ramalama
# See https://ramalama.ai/
#=================================
RUN dnf install -y python3-pip
ARG RAMALAMA_VERSION=0.12.2
RUN pip install --root-user-action=ignore --no-cache-dir ramalama==${RAMALAMA_VERSION}

################################
# Packages: clean up
################################
RUN dnf clean all && \
    rm -rf /var/cache/dnf \
           /var/lib/dnf \
           /var/log/*.log


################################
# Services: configuration
################################

#=================================
# NVIDIA Container Toolkit
#=================================
# Service to generate /etc/cdi/nvidia.yaml on first boot
# See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support
COPY <<EOF /usr/lib/systemd/system/nvidia-driver-firstboot.service
[Unit]
# For more information see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html
Description=Generate /etc/cdi/nvidia.yaml
Before=basic.target

[Service]
Type=oneshot
ExecStart=nvidia-ctk cdi generate
RemainAfterExit=yes
StandardOutput=/etc/cdi/nvidia.yaml

[Install]
WantedBy=basic.target
EOF
RUN ln -s ../nvidia-driver-firstboot.service /usr/lib/systemd/system/default.target.wants

