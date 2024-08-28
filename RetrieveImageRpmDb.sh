#!/bin/bash

usage()
{
cat << EOF

Usage: `basename $0` options
The script retrieve the RPM database from a docker image.

OPTIONS:
    -h    Show this message
    -i    <docker image:version>

    -p    RPM database prefix path (optional)
    -z    zip the RPM database folder (optional)
    -r    remove docker image after RPM database retrieve (optional)

Example: `basename $0` -i armdocker.rnd.ericsson.se/proj-enm/eric-enmsg-web-push-service:latest -z -p /tmp

EOF
}

RM_DOCKER_IMAGE=
ZIP_RPM_DB_FOLDER=
LOCAL_RPM_DB_PATH=
while getopts "hrzi:p:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        i)
            DOCKER_IMAGE=$OPTARG
            ;;
        r)
            RM_DOCKER_IMAGE=true
            ;;
        p)
            LOCAL_RPM_DB_PATH=$OPTARG/
            ;;
        z)
            ZIP_RPM_DB_FOLDER=true
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

# Check the parameter value
if [[ -z $DOCKER_IMAGE ]]; then
    echo "Error! No parameter provided."
    usage
    exit 1
fi

# Get the docker image name without version
arrIN=(${DOCKER_IMAGE//:/ })
IMAGE_NAME=${arrIN[0]}
IMAGE_VERSION=${arrIN[1]}
if [[ -z $IMAGE_VERSION ]]; then
    IMAGE_VERSION=latest
fi

SG_NAME=`basename ${IMAGE_NAME}`
PREFIX_RPM_DB="RpmDB_"
CONTAINER_NAME=${PREFIX_RPM_DB}${SG_NAME}_${IMAGE_VERSION}
RPM_DB_FOLDER_NAME=${CONTAINER_NAME}
FULL_RPM_DB_FOLDER_NAME=${LOCAL_RPM_DB_PATH}${CONTAINER_NAME}

IMAGE_RPM_DB_PATH=/var/lib/rpm/

# Create the container
docker create --name ${CONTAINER_NAME} ${DOCKER_IMAGE} &>/dev/null

# Remove destination folder
rm -r -f ${FULL_RPM_DB_FOLDER_NAME}

# Retrieve RPM database from container
#echo "Retrieve RPM database from '${DOCKER_IMAGE}' ..."
docker cp ${CONTAINER_NAME}:${IMAGE_RPM_DB_PATH} ${FULL_RPM_DB_FOLDER_NAME}

if [[ $ZIP_RPM_DB_FOLDER ]]; then
# Zip the RPM database folder and remove the folder
    if [[ $LOCAL_RPM_DB_PATH ]]; then
        cd ${LOCAL_RPM_DB_PATH}
    fi
    zip -q -r ${RPM_DB_FOLDER_NAME}.zip ${RPM_DB_FOLDER_NAME}
    rm -r -f ${RPM_DB_FOLDER_NAME}
fi

# Remove the container
docker container rm ${CONTAINER_NAME} &>/dev/null

if [[ $RM_DOCKER_IMAGE ]]; then
# Remove docker image
    docker image rm ${DOCKER_IMAGE}
fi
