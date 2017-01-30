#!/usr/bin/env bash

########################################################################################
# Variables
########################################################################################

DIR=`pwd`
USER=`id -u`
GROUP=`id -g`

ACBUILD="sudo acbuild"

IMG_URL=https://fr.alpinelinux.org/alpine/v3.5/releases/x86_64/alpine-minirootfs-3.5.0-x86_64.tar.gz
IMG_TAR=$DIR/alpine-minirootfs-3.5.0-x86_64.tar.gz
IMG=alpine-3.5.0-sh
IMG_ACI=${IMG}.aci

########################################################################################
# Functions
########################################################################################

usage () {
	echo "$0"
	echo "usage : {build|clean}"
	exit 5
}

acbuildend () {
	export EXIT=$?;
	$ACBUILD --debug end
	exit $EXIT;
}

build () {
	curl $IMG_URL -o $IMG_TAR
	set -e
	$ACBUILD --debug begin
	trap acbuildend EXIT
	sudo tar -xzf $IMG_TAR -C $DIR/.acbuild/currentaci/rootfs
	sudo chmod 755 $DIR/.acbuild/currentaci/rootfs
	$ACBUILD --debug set-name $IMG
	$ACBUILD --debug run -- apk update
	$ACBUILD --debug set-exec /bin/sh
	$ACBUILD --debug write --overwrite $IMG_ACI
	sudo chown ${USER}:${GROUP} $IMG_ACI
	trap '' EXIT
	set +e
	$ACBUILD --debug end
	[ -f $IMG_TAR ] && rm -f $IMG_TAR
	sudo rkt fetch --insecure-options=image alpine-3.5.0-sh.aci
}

clean () {
	[ -f $IMG_TAR ] && rm -f $IMG_TAR
	[ -f $DIR/$IMG_ACI ] && rm -f $DIR/$IMG_ACI
	sudo rkt image list | grep $IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		UUID_IMG=`sudo rkt image list | grep $IMG | awk '{print $1}'`
		sudo rkt image rm $UUID_IMG
		sudo rkt image gc
	fi
}

########################################################################################
# Main
########################################################################################

if [ $# -ne 1 ]
then
	usage
fi

case $1 in
	build)
		build
		;;
	clean)
		clean
		;;
	*)
		usage
		;;
esac

exit 0
