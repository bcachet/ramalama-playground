## Build QCOW out of Container with bootc-image-builder

Mostly following what I learn reading [RedHat documentation about bootc-image-builder](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/creating-bootc-compatible-base-disk-images-with-bootc-image-builder_using-image-mode-for-rhel-to-build-deploy-and-manage-operating-systems)

Build image
```sh
❯ sudo podman build \
    --tag localhost/fedora-bootc:ramalama \
    .
```

Build QCOW out of container image with [boot-image-builder](https://osbuild.org/docs/bootc/)
```sh
❯ sudo podman run \
          --rm \
          -it \
          --privileged \
          --pull=newer \
          --security-opt label=type:unconfined_t \
          -v ./output:/output \
          -v ./bootc-image-builder-config.toml:/config.toml \
          -v /var/lib/containers/storage:/var/lib/containers/storage \
          quay.io/centos-bootc/bootc-image-builder:latest \
          --type qcow2 \
          --use-librepo=True \
          --rootfs ext4 \
          localhost/fedora-bootc:ramalama
```

Upload QCOW to SOS
```sh
exo -A prod storage upload \
  --acl=public-read \
  output/qcow2/disk.qcow2 \
  sos://vie2-bucket/fedora-ramalma.qcow
```

Generate template out of QCOW
```sh
exo -A prod c template register \
  fedora-ramalama \
  https://sos-at-vie-2.exo.io/vie2-bucket/fedora-ramalma.qcow \
  $(md5sum output/qcow2/disk.qcow2 | cut -d ' ' -f 1) \
  --username core \
  --zone at-vie-2
```

Create VM out of this template
```sh
exo -A prod c i create ai-runner \
  --zone at-vie-2 \
  --template fedora-ramalama \
  --template-visibility private \
  --instance-type gpua5000.medium \
  --cloud-init cloud-init \
  --disk-size 100
```

## TODO

- [ ] [Integration test of bootc image](https://github.com/secureblue/bootc-integration-test-action)
- [ ] Evaluate [uCore](https://github.com/ublue-os/ucore)

## Generating infrastructure
> [!WARNING]
> Terraform not in sync with bootc-image-builder approach
```shell
bw login
bw sync
export SECRETS=$(bw get item "Exoscale IAM Key Prod bertrand@exoscale.ch")
export TF_VAR_exoscale_api_key=$(echo $SECRETS | jq -r '.login.username')
export TF_VAR_exoscale_secret_key=$(echo $SECRETS | jq -r '.login.password')
export EXOSCALE_API_ENDPOINT='https://api-at-vie-1.exoscale.com/v2'
direnv allow
cat << EOF > .envrc
export TF_VAR_exoscale_api_key=$TF_VAR_exoscale_api_key
export TF_VAR_exoscale_secret_key=$TF_VAR_exoscale_secret_key
EOF
```
