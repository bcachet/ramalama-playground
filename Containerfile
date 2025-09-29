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
# NVIDIA Drivers and NVIDIA Container Toolkit
#=================================
RUN <<EOF
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install the kernel devel and kernel header tools
# We get the kernel that is being used in THE BASE IMAGE by doing /usr/lib/modules && echo *, then we install the kernel-devel for that kernel
# SOMETIMES this messes up if the "base" image has an outdated kernel vs the one you get from dnf
dnf install -y kernel-devel-$(cd /usr/lib/modules && echo *)

# Install the nvidia drivers
dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

# Install NVIDIA container toolkit
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
dnf install -y nvidia-container-toolkit

# Blacklist the nouveau driver to ensure NVIDIA drivers function properly
echo "blacklist nouveau" > /etc/modprobe.d/blacklist_nouveau.conf

# See: "Kernel Open" on:
# https://rpmfusion.org/Howto/NVIDIA?highlight=%28%5CbCategoryHowto%5Cb%29
# Starting 515xx and above, to support the 5000 series and newer cards, the kernel needs to be "open" to allow the nvidia drivers to work when compiling with akmods.
sh -c 'echo "%_with_kmod_nvidia_open 1" > /etc/rpm/macros.nvidia-kmod'

# Add `options nvidia NVreg_OpenRmEnableUnsupportedGpus=1` to /etc/modprobe.d/nvidia.conf
# which will enable the 5000 series GPUs to work with the nvidia drivers.
echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" > /etc/modprobe.d/nvidia.conf
EOF

# Build kmods which runs on boot.
# The reasoning for the script is that sometimes the kernel version is different on the base images vs what is actually on 
# dnf update, so we have to "fake it till you make it" scenario.
COPY --chmod=0755 dkms.sh /tmp
RUN <<EOF
dnf install -y dkms
/tmp/dkms.sh
EOF


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

# Enable necessary services to be started at boot
RUN systemctl enable nvidia-toolkit-firstboot.service

