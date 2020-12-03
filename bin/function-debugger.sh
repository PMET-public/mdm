#!/usr/bin/env bash
set -e

# shellcheck source=lib.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh" || :


#get_wildcard_cert_and_key_for_mdm_domain
#cp_wildcard_mdm_domain_cert_and_key_for_subdomain "$hostname"
get_cert_utc_end_date_for_domain ".$mdm_domain"