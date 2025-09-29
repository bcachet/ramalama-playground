################################
# Container to be used with bootc-image-builder
# See https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/
################################

FROM quay.io/fedora/fedora-bootc:42

################################
# Packages: installation
################################
# Installed packages:
# * ramalama (https://ramalama.ai)
# * nvidia-container-toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
# * NVIDIA CUDA drivers (https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
# * dkms to build NVIDIA driver kernel modules (https://linux.die.net/man/8/dkms)
# * cloud-init to fetch SSH keys and users from cloud provider metadata (https://cloudinit.readthedocs.io/en/latest/)

#=================================
# NVIDIA cuda/container-toolkit repositories
#=================================
RUN curl -s -L https://developer.download.nvidia.com/compute/cuda/repos/fedora42/x86_64/cuda-fedora42.repo | \
    tee /etc/yum.repos.d/cuda-fedora42.repo
RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
    tee /etc/yum.repos.d/nvidia-container-toolkit.repo

#=================================
# Install packages
#=================================
ARG CUDA_DRIVERS_VERSION=580.82.07
ARG NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8
ARG CLOUDINIT_VERSION=24.2
ARG DKMS_VERSION=3.2.2
ARG RAMALAMA_VERSION=0.12.2
RUN <<EOF
set -euox pipefail
dnf install -y --setopt=install_weak_deps=False \
    cuda-drivers-${CUDA_DRIVERS_VERSION} \
    nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    cloud-init-${CLOUDINIT_VERSION} \
    dkms-${DKMS_VERSION} \
    ramalama-${RAMALAMA_VERSION}    
dnf clean all
rm -rf /var/cache/dnf \
       /var/lib/dnf \
       /var/log/*.log
EOF

#=================================
# NVIDIA: build kmods
#=================================
# Build the NVIDIA kernel modules for the kernel version installed on the filesystem.
RUN <<EOF
set -euox pipefail

export KERNEL_VERSION=$(cd /usr/lib/modules && echo *)

# Create a fake uname that only responds to -r with the kernel version we want.
cat >/tmp/fake-uname <<EOH
#!/usr/bin/env bash

if [ "\$1" == "-r" ] ; then
  echo ${KERNEL_VERSION}
  exit 0
fi

exec /usr/bin/uname \$@
EOH

# Use the fake uname in PATH to build the kmods for the desired kernel version.
install -Dm0755 /tmp/fake-uname /tmp/bin/uname

PATH=/tmp/bin:$PATH dkms autoinstall -k ${KERNEL_VERSION}
rm -f /tmp/fake-uname /tmp/bin/uname
EOF


################################
# Services: configuration
################################

#=================================
# NVIDIA Container Toolkit
#=================================
# Service to generate /etc/cdi/nvidia.yaml on first boot
# See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support
RUN mkdir -p /etc/cdi
COPY <<EOF /usr/lib/systemd/system/nvidia-toolkit-firstboot.service
[Unit]
# For more information see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html
Description=Generate /etc/cdi/nvidia.yaml to be used by Podman
# Ensure we do this AFTER the nvidia-drivers.service
After=nvidia-drivers.service
# Must be done BEFORE the podman-restart.service or podman.service (if using API)
# since /etc/cdi/nvidia.yaml is used by podman to access GPU
Before=podman-restart.service podman.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/nvidia-ctk cdi generate | tee /etc/cdi/nvidia.yaml'
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=basic.target

EOF

# Ensure nvidia-toolkit-firstboot to be started at boot
RUN systemctl enable nvidia-toolkit-firstboot.service

#=================================
# cloud-init
#=================================
# Ensure cloud-init service to be started at boot
RUN systemctl enable cloud-init.service
