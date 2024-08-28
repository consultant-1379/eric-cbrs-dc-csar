#!/bin/bash
#------------------------------------------------------------------------
#
#
#       COPYRIGHT (C) 2022                  ERICSSON AB, Sweden
#
#       The  copyright  to  the document(s) herein  is  the property of
#       Ericsson Radio Systems AB, Sweden.
#
#       The document(s) may be used  and/or copied only with the written
#       permission from Ericsson Radio Systems AB  or in accordance with
#       the terms  and conditions  stipulated in the  agreement/contract
#       under which the document(s) have been supplied.
#
#------------------------------------------------------------------------

DATE=date
DIRNAME=dirname
DOCKER=docker
ECHO=echo
REALPATH=realpath


_log() {
  local _level_="${1}"
  local _text_="${2}"
  _date_=$( ${DATE} +"%d/%b/%y_%H:%M:%S" )
  ${ECHO} -e "${_level_} - ${_date_} - ${_text_}"
}

info() {
  _log "INFO" "${*}"
}

error() {
  _log "ERROR" "${*}"
}

usage() {
  ${ECHO} "${0} -r <repository> -t <docker.tar> [-i <images.txt>]"
  ${ECHO} -e "\tWhere -r is the URL to the local docker registry"
  ${ECHO} -e "\tWhere -t the path to Files/images/docker.tar"
  ${ECHO} -e "\tWhere -i the path to Files/images.txt"
}

###############################################################################
#
# Load the CSAR image repository from the docker.tar
# Arguments:
#   $1 - The CSAR docker.tar to load.
#   $2 - The CSAR images.txt to use to verify all images were loaded.
#
###############################################################################
docker_load() {
  local _tar_=${1}
  local _images_=${2}

  info "Loading ${_tar_} ..."
  ${DOCKER} load --input ${_tar_} 2>&1 || exit 1

  for _image_ in $(<${_images_}); do
    info "Verifying ${_image_} ..."
    _sout_=$( ${DOCKER} image inspect ${_image_} 2>&1 )
    if [ $? -eq 0 ]; then
      info "${_image_} OK"
    else
      error "${_image_} FAILED"
      error "${_sout_}"
      exit 1
    fi
  done
}

###############################################################################
#
# Re-tag images to a new repository URL
# Arguments:
#   $1 - File containing list of images to re tag
#   $2 - The new repository URL to re-tag the images too
#   $3 - File to output the new re-tagged image tags
#
###############################################################################
retag_images() {
  local _images_=${1}
  local _site_local_repo_=${2}
  local _retagged_list_=${3}
  info "Retagging images ..."
  $ECHO >${_retagged_list_}
  for _image_ in $(<${_images_}); do
    _current_tag_repo_=$(echo ${_image_} | cut -d'/' -f1)
    _current_tag_path_=$(echo ${_image_} | cut -d'/' -f2-)
    if [ "${_current_tag_repo_}" == "${_site_local_repo_}" ]; then
      info "No need to re-tag ${_image_}"
    else
      _new_tag_="${_site_local_repo_}/${_current_tag_path_}"
      ${ECHO} ${_new_tag_} >>${_retagged_list_}

      ${DOCKER} image inspect ${_new_tag_} >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        info "Image already re-tagged: ${_new_tag_}"
      else
        info "Re-tagging ${_image_}"
        info "\t-> ${_new_tag_}"
        ${DOCKER} tag ${_image_} ${_new_tag_} 2>&1 || exit 1
      fi
    fi
    ${DOCKER} image inspect ${_image_} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      ${DOCKER} rmi --force ${_image_} 2>&1 || exit 1
    fi
  done
}

###############################################################################
#
# Push re-tagged images to the new repository
# Arguments:
#   $1 - File containing list of re-tagged images
#
###############################################################################
push_retagged_images() {
  local _retagged_=${1}
  for _image_ in $(<${_retagged_}); do
    _repo_=$(echo ${_image_} | cut -d'/' -f1)
    echo "Pushing ${_image_} to ${_repo_}"
    ${DOCKER} push ${_image_} 2>&1 || exit 1
    ${DOCKER} rmi --force ${_image_} 2>&1 || exit 1
  done
}

###############################################################################
# Main flow
###############################################################################
DOCKER_REGISTRY_URL=
DOCKER_TAR=
IMAGES=
while getopts "r:t:i:" _option_; do
  case "${_option_}" in
  r)
    DOCKER_REGISTRY_URL=${OPTARG}
    ;;
  t)
    DOCKER_TAR=$(${REALPATH} ${OPTARG})
    ;;
  i)
    IMAGES=$(${REALPATH} ${OPTARG})
    ;;
  *)
    usage
    exit 2
    ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "${DOCKER_REGISTRY_URL}" ] || [ -z "${DOCKER_TAR}" ]; then
  usage
  exit 2
fi

if [ ! -f ${DOCKER_TAR} ]; then
  error "File ${DOCKER_TAR} not found"
  exit 1
fi

if [ -z "${IMAGES}" ]; then
  IMAGES="$(${DIRNAME} ${DOCKER_TAR})/../images.txt"
  IMAGES="$(${REALPATH} ${IMAGES})"
fi
if [ ! -f ${IMAGES} ]; then
  error "File ${IMAGES} not found"
  exit 1
fi

info "Loading ${DOCKER_TAR} to ${DOCKER_REGISTRY_URL}"

docker_load ${DOCKER_TAR} ${IMAGES}
retag_images ${IMAGES} ${DOCKER_REGISTRY_URL} ${IMAGES}.retagged
push_retagged_images ${IMAGES}.retagged
info "Loaded, re-tagged and pushed to docker registry ${DOCKER_REGISTRY_URL}"
