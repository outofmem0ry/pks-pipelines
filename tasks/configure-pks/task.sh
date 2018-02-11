#!/bin/bash

set -eu

domains=(
    "*.${SYSTEM_DOMAIN}"
    "*.${UAA_DOMAIN}"
  )
data=$(echo $domains | jq --raw-input -c '{"domains": (. | split(" "))}')
certificates=$(om-linux \
     --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
     --username "$OPS_MGR_USR" \
     --password "$OPS_MGR_PWD" \
     --skip-ssl-validation \
     curl \
     --silent \
     --path "/api/v0/certificates/generate" \
     -x POST \
     -d $data
   )
SSL_CERT=`echo $certificates | jq --raw-output '.certificate'`
SSL_PRIVATE_KEY=`echo $certificates | jq --raw-output '.key'`

pks_network=$(
  jq -n \
    --arg az_1_name "$az_1_name" \
    --arg infra_network_name "$infra_network_name" \
    --arg services_network_name "$services_network_name" \
  '
  {
    "singleton_availability_zone": {
      "name": $az_1_name
    },
    "other_availability_zones": [
      {
        "name": $az_1_name
      }
    ],
    "network": {
      "name": $infra_network_name
    },
    "service_network": {
      "name": $services_network_name
    }
  }
  '
)

pks_properties=$(
  jq -n \
    --arg ops "$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
    --arg az_1_name "$az_1_name" \
    --arg vcenter_host "$vcenter_host" \
    --arg vcenter_usr "$vcenter_usr" \
    --arg vcenter_pwd "$vcenter_pwd" \
    --arg vcenter_data_center "$vcenter_data_center" \
    --arg om_data_store "$om_data_store" \
    --arg bosh_vm_folder "$bosh_vm_folder" \
    --arg uaa_url "$uaa_url" \
    --arg SSL_PRIVATE_KEY "$SSL_PRIVATE_KEY" \
    --arg SSL_CERT "$SSL_CERT" \
  '
  {
    ".properties.cloud_provider": {
      "value": "vSphere"
    },
    ".properties.cloud_provider.vsphere.vcenter_creds": {
      "value": {
        "identity": $vcenter_usr,
        "password": $vcenter_pwd
      }
    },
    ".properties.cloud_provider.vsphere.vcenter_ip": {
      "value": $vcenter_host
    },
    ".properties.cloud_provider.vsphere.vcenter_dc": {
      "value": $vcenter_data_center
    },
    ".properties.cloud_provider.vsphere.vcenter_ds": {
      "value": $om_data_store
    },
    ".properties.cloud_provider.vsphere.vcenter_vms": {
      "value": $bosh_vm_folder
    },
    ".properties.network_selector": {
      "value": "flannel"
    },
    ".properties.plan1_selector": {
      "value": "Plan Active"
    },
    ".properties.plan1_selector.active.name": {
      "value": "small"
    },
    ".properties.plan1_selector.active.description": {
      "value": "Default small plan for K8s cluster",
    },
    ".properties.plan1_selector.active.az_placement": {
      "value": $az_1_name
    },
    ".properties.plan1_selector.active.authorization_mode": {
      "value": "rbac"
    },
    ".properties.plan1_selector.active.master_vm_type": {
      "value": "medium"
    },
    ".properties.plan1_selector.active.master_persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan1_selector.active.worker_vm_type": {
      "value": "medium"
    },
    ".properties.plan1_selector.active.persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan1_selector.active.worker_instances": {
      "value": 2
    },
    ".properties.plan1_selector.active.errand_vm_type": {
      "value": "micro"
    },
    ".properties.plan1_selector.active.addons_spec": {
      "value": null
    },
    ".properties.plan1_selector.active.allow_privileged_containers": {
      "value": false
    },
    ".properties.plan2_selector": {
      "value": "Plan Active"
    },
    ".properties.plan2_selector.active.name": {
      "value": "medium"
    },
    ".properties.plan2_selector.active.description": {
      "value": "Medium workloads",
    },
    ".properties.plan2_selector.active.az_placement": {
      "value": $az_1_name
    },
    ".properties.plan2_selector.active.authorization_mode": {
      "value": "rbac",
    },
    ".properties.plan2_selector.active.master_vm_type": {
      "value": "large"
    },
    ".properties.plan2_selector.active.master_persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan2_selector.active.worker_vm_type": {
      "value": "medium"
    },
    ".properties.plan2_selector.active.persistent_disk_type": {
      "value": "10240"
    },
    ".properties.plan2_selector.active.worker_instances": {
      "value": 3
    },
    ".properties.plan2_selector.active.errand_vm_type": {
      "value": "micro"
    },
    ".properties.plan2_selector.active.addons_spec": {
      "value": null
    },
    ".properties.plan2_selector.active.allow_privileged_containers": {
      "value": false
    },
    ".properties.plan3_selector": {
      "value": "Plan Inactive",
      "optional": false
    },
    ".properties.uaa_url": {
      "value": $uaa_url
    },
    ".properties.uaa_pks_cli_access_token_lifetime": {
      "value": 86400
    },
    ".properties.uaa_pks_cli_refresh_token_lifetime": {
      "value": 172800
    },
    ".properties.syslog_migration_selector": {
      "value": "disabled"
    },
    ".pivotal-container-service.pks_tls": {
      "value": {
        "private_key_pem": $SSL_PRIVATE_KEY,
        "cert_pem": $SSL_CERT
      }
    }
  }

  '
)

om-linux --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  --skip-ssl-validation \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  configure-product \
  --product-name pivotal-container-service \
  --product-network "$pks_network"

om-linux --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  --skip-ssl-validation \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  configure-product \
  --product-name pivotal-container-service \
  --product-properties "$pks_properties"
