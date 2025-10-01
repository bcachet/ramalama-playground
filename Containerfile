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

# Provide required NVIDIA repositories
COPY container/etc/yum.repos.d /etc/yum.repos.d

# Install packages
ARG CUDA_DRIVERS_VERSION=580.82.07
ARG NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8
ARG CLOUDINIT_VERSION=24.2
ARG DKMS_VERSION=3.2.2
ARG RAMALAMA_VERSION=0.12.2
RUN <<EOF
set -eux -o pipefail
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

################################
# Kernel configuration
################################
# Build the NVIDIA kernel modules for the kernel version installed on the filesystem
COPY container/tmp/bin /tmp/bin
RUN <<EOF
set -eux -o pipefail
export KERNEL_VERSION=$(cd /usr/lib/modules && echo *)
PATH=/tmp/bin:$PATH dkms autoinstall -k ${KERNEL_VERSION}
rm -rf /tmp/bin
EOF

################################
# Services: configuration
################################
COPY container/usr/lib/systemd/system/ usr/lib/systemd/system/
# Ensure services to be started at boot
RUN systemctl enable \
        nvidia-toolkit-firstboot.service \
        ramalama-serve.service \
        cloud-init.service
