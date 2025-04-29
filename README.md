```shell
bw login
export SECRETS=$(bw get item "Exoscale IAM Unrestricted Preprod")
export TF_VAR_exoscale_api_key=$(echo $SECRETS | jq -r '.login.username')
export TF_VAR_exoscale_secret_key=$(echo $SECRETS | jq -r '.login.password')
export EXOSCALE_API_ENDPOINT='https://ppapi-ch-gva-2.exoscale.com/v2'
```
