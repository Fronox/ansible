#!/bin/sh
set -e

VERIFY_TLS="{{ waldur_api_verify_tls | default('false') | string }}"

if [ $VERIFY_TLS = "false" ]; then
  export NO_CHECK_CERTIFICATE="--no-check-certificate"
fi

while true; do
  echo "[+] Fetching users config file"
  # Creating an empty file to handle a case when a response is empty
  touch /tmp/offering-users-config.cfg

  RESOURCE_UUID=$(wget $NO_CHECK_CERTIFICATE --quiet -O- --header="Authorization: Token {{ waldur_api_token }}" \
  {{ waldur_api_url }}marketplace-order-items/{{ waldur_order_item_uuid }}/ | jq -r ".resource_uuid")

  if [ $RESOURCE_UUID = "null" ] || [ $RESOURCE_UUID = "" ]; then
    echo "[+] Resource is not created yet, skipping users fetching"
    continue
  fi

  wget $NO_CHECK_CERTIFICATE --quiet --header="Authorization: Token {{ waldur_api_token }}" \
    {{ waldur_api_url }}marketplace-resources/$RESOURCE_UUID/glauth_users_config/ \
    -O /tmp/offering-users-config.cfg

  DIFF=true
  if [ -f /tmp/prev-offering-users-config.cfg ]; then
    echo "[+] Executing diff with previous users config file"
    diff /tmp/prev-offering-users-config.cfg /tmp/offering-users-config.cfg \
      && echo "[+] There are no changes in the new glauth config, skipping merge" \
      && DIFF=false
  else
    echo "[+] Previous user config file is missing, skipping diff"
  fi

  if [ $DIFF = true ]; then
    echo "[+] Merging preconfig file with users config one"
    cat /etc/glauth/glauth-preconfig.cfg /tmp/offering-users-config.cfg > /etc/glauth/config.cfg

    echo "[+] Cleanup"
    mv /tmp/offering-users-config.cfg /tmp/prev-offering-users-config.cfg
  fi
  sleep 300 # sleep for 5 minutes
done
