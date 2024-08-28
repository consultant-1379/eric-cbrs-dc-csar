#!/bin/bash

GREP=grep
HELM=helm
KUBECTL=kubectl

usage(){
  echo "Uninstall a helm chart base on release name"
  echo "$0 -n <namespace> -r release_name"
}

_uninstall_release() {
  local _chart_=$1
  if ${HELM} list --all -n ${_NAMESPACE_} | grep -q ${_chart_} ; then
    echo "Uninstalling ${_chart_} ..."
    if helm uninstall --help | grep -q -- "--wait" ; then
      _wait_="--wait"
    fi
    ${HELM} uninstall -n ${_NAMESPACE_} ${_chart_} ${_wait_}
  else
    echo "Chart ${_chart_} not installed."
  fi
  echo "Waiting for pods to terminate ..."
  while ${KUBECTL} -n ${_NAMESPACE_} get pods | ${GREP} -q "Terminating" ; do
    sleep 1
  done
}

_delete_labeled_resource(){
  _type_=$1
  _selector_=$2
  echo "Deleting ${_type_} ${_selector_} ..."
  _pvcs_=$( ${KUBECTL} -n ${_NAMESPACE_} get ${_type_} -l "${_selector_}" -o jsonpath='{.items[*].metadata.name}' )
  if [[ "${_pvcs_}" != "" ]] ; then
    ${KUBECTL} -n ${_NAMESPACE_} delete ${_type_} --ignore-not-found ${_pvcs_}
  fi
}

_delete_secret_by_sa_name(){
  _sa_name_="${1}"
  _secret_=$( ${KUBECTL} get secret -n ${_NAMESPACE_} -o=jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="${_sa_name_}")].metadata.name}' )
  if [[ ! -z "${_secret_}" ]] ; then
    echo "Deleting ${_sa_name_} secret ${_secret_} ..."
    ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} "${_secret_}"
  fi
}

_delete_pvcs() {
  _delete_labeled_resource "pvc" $1
}

_delete_secrets() {
  echo "Deleting secrets ..."
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-data-distributed-coordinator-ed-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-data-distributed-coordinator-ed-etcdctl-client-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-data-distributed-coordinator-ed-peer-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-data-document-database-pg-cm-customuser-brminternal-secret
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-data-document-database-pg-cm-customuser-brminternal-secret-emergency
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-sec-key-management-client-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-sec-key-management-kms-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-sec-sip-tls-bootstrap-ca-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-sec-sip-tls-trusted-root-cert
  ${KUBECTL} delete secret --ignore-not-found -n ${_NAMESPACE_} eric-sec-sip-tls-trusted-root-cert

  _delete_secret_by_sa_name "eric-cm-mediator-hook"
  _delete_secret_by_sa_name "eric-data-document-database-pg-cm-hook"
  _delete_secret_by_sa_name "eric-data-document-database-pg-fm-hook"
  _delete_secret_by_sa_name "postgres-hook"
}

_delete_configmaps() {
  echo "Deleting configmaps ..."
  ${KUBECTL} delete configmap sip-tls -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete configmap sip-tls-supervisor -n ${_NAMESPACE_} --ignore-not-found
}

_delete_internalcertificates() {
  echo "Deleting internalcertificates ..."
  ${KUBECTL} delete internalcertificates eric-data-document-database-pg-cm-customuser-brminternal-cr -n ${_NAMESPACE_} --ignore-not-found
}

_delete_roles(){
  echo "Deleting roles ..."
  ${KUBECTL} delete role eric-data-document-database-pg-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete role eric-data-document-database-pg-cm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete role eric-data-document-database-pg-fm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete role postgres-hook -n ${_NAMESPACE_} --ignore-not-found
}

_delete_rolebindings(){
  echo "Deleting rolebindings ..."
  ${KUBECTL} delete rolebinding eric-data-document-database-pg-cm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete rolebinding eric-data-document-database-pg-fm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete rolebinding postgres-hook -n ${_NAMESPACE_} --ignore-not-found
}

_delete_serviceaccounts(){
  echo "Deleting serviceaccounts ..."
  ${KUBECTL} delete serviceaccount eric-cm-mediator-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete serviceaccount eric-data-document-database-pg-cm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete serviceaccount eric-data-document-database-pg-fm-hook -n ${_NAMESPACE_} --ignore-not-found
  ${KUBECTL} delete serviceaccount postgres-hook -n ${_NAMESPACE_} --ignore-not-found
}

if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 2
fi

while getopts "n:r:" o; do
    case "${o}" in
        n)
          _NAMESPACE_=${OPTARG};;
        r)
          _RELEASE_=${OPTARG};;
        h|*)
            usage
            exit 2;;
    esac
done
shift $((OPTIND-1))

if [[ -z ${_RELEASE_} ]] || [[ -z ${_NAMESPACE_} ]] ; then
  usage
  exit 2
fi


_uninstall_release "${_RELEASE_}"
_delete_pvcs "app.kubernetes.io/instance=${_RELEASE_}"
_delete_pvcs "release=${_RELEASE_}"

_delete_internalcertificates
_delete_rolebindings
_delete_serviceaccounts
_delete_roles
_delete_secrets
_delete_configmaps

