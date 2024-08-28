#!/bin/bash

CAT=cat
CP=cp
DOCKER=docker
ECHO=echo
RM=rm
SED=sed
SUDO=sudo
TIME=time
UUIDGEN=uuidgen

AM_PACKAGE_IMAGE="armdocker.rnd.ericsson.se/proj-am/releases/eric-am-package-manager:2.0.28"
CSAR_PACKAGE_NAME="eric-cbrs-dc-package"

BUILD="build"
mkdir ${BUILD} 
cp "manifest/${CSAR_PACKAGE_NAME}.mf" "${BUILD}/"
cp "vnfds/${CSAR_PACKAGE_NAME}.yaml" "${BUILD}/"

T_MANIFEST="manifest/${CSAR_PACKAGE_NAME}.mf"
T_VNFD="vnfds/${CSAR_PACKAGE_NAME}.yaml"

O_MANIFEST="${BUILD}/${CSAR_PACKAGE_NAME}.mf"
O_VNFD="${BUILD}/${CSAR_PACKAGE_NAME}.yaml"

VERSION=$( ${CAT} VERSION_PREFIX )
PRODUCT_SET=${VERSION}

update_manifest() {
  ${ECHO} "Updating manifest ${T_MANIFEST}"
 _version_="CXP1234567_${VERSION}"
 _date_=$( date +"%Y-%m-%dT%H:%m:%SZ" )
  ${SED} -e "/^vnf_package_version:/s/.*/vnf_package_version: ${_version_}/" \
         -e "/^vnf_release_date_time:/s/.*/vnf_release_date_time: ${_date_}/" \
         ${T_MANIFEST} > ${O_MANIFEST}
}

update_vnfds() {
  _vnfd_="${1}"
  _chart_=$( basename "${2}" )
#  _uuid_=$( ${UUIDGEN} )
  _uuid_="d7fd631a-3605-4017-8dc4-3b86bfede5af"
  ${ECHO} "Updating VNFD ${_vnfd_}"

  ${CP} "${_vnfd_}" "${O_VNFD}"
  ${SED} -i "s/<<VERSION>>/$VERSION/g" "${O_VNFD}"
  ${SED} -i "s/<<PRODUCT_SET>>/${PRODUCT_SET}/g" "${O_VNFD}"
  ${SED} -i "s/<<DESCRIPTOR_ID>>/${_uuid_}/g" "${O_VNFD}"
  ${SED} -i "s/<<CHART>>/${_chart_}/g" "${O_VNFD}"
}

build_csar() {
  _chart_="${1}"
  _vnfd_="${2}"
  _light_="${3}"
  if [[ "${_light_}" -eq 1 ]] ; then
    _light_="--no-image"
  else
    unset _light_
  fi
  _csar_name_="${CSAR_PACKAGE_NAME}-${VERSION}"

  ${ECHO} "Building CSAR ${_csar_name_}"
  ${ECHO} -e "\tMANIFEST: ${O_MANIFEST}"
  ${ECHO} -e "\tVNFD: ${_vnfd_}"

  ${RM} -f ${BUILD}/*.tgz
  ${CP} "${_chart_}" ${BUILD}/

  _chart_args_="tags.eric-cbrs-dc-common=true,tags.eric-cbrs-dc-mediation=true,cmyp-brm.user=u,cmyp-brm.encryptedPass=p,eric-ran-security-service-init.secrets.ldap.adminuser=u,eric-ran-security-service-init.secrets.ldap.adminpasswd=p"
  ${TIME} ${DOCKER} run --rm \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume "${PWD}":"${PWD}" \
      --workdir "${PWD}" \
      "${AM_PACKAGE_IMAGE}" generate \
      --helm-dir ${BUILD} \
      --name "${_csar_name_}" \
      --scripts scripts \
      --set ${_chart_args_} \
      --manifest "${O_MANIFEST}" \
      --history history/ChangeLog.txt \
      --definitions definitions/etsi_nfv_sol001_vnfd_2_5_1_types.yaml \
      --vnfd "${O_VNFD}" \
      ${_light_} \
      || exit 1

  ${ECHO} "Generated ${_csar_name_}.csar"
}

clean() {
  ${RM} -rf ${BUILD}/*

  if [[ -d source ]] ; then
    ${SUDO} ${RM} -rf source
  fi
  if [[ -f docker.tar ]] ; then
    ${SUDO} ${RM} docker.tar
  fi
  if [[ -f ${CSAR_PACKAGE_NAME}*.csar ]] ; then
    ${SUDO} ${RM} -f ${CSAR_PACKAGE_NAME}*.csar
  fi
}

usage() {
  echo "$0 -C <chart> [-lc]"
  echo -e "\t-C: CBRS chart file"
  echo -e "\t-l: Build light version"
  echo -e "\t-c: Clean previous build"
}

if [[ $# -eq 0 ]] ; then
  usage
  exit 2
fi

_CLEAN_=0
_LIGHT_=0
_CHART_=

while getopts "lcC:" _o_; do
  case "${_o_}" in
    l)
      _LIGHT_=1;;
    c)
      _CLEAN_=1;;
    C)
      _CHART_=$( realpath "${OPTARG}" );;
    h|*)
        usage
        exit 2
        ;;
  esac
done

if [[ ${_CLEAN_} -eq 1 ]] ; then
  clean
fi

if [[ ! -z "${_CHART_}" ]] ; then
  update_manifest
  update_vnfds ${T_VNFD} "${_CHART_}"
  build_csar "${_CHART_}" ${T_VNFD} "${_LIGHT_}"
fi
