#!/usr/bin/env bash

########################################################################################
# Variables
########################################################################################

DIR=`pwd`
USER=`id -u`
GROUP=`id -g`

. $DIR/front.env

FRONT_IMG=front_rundeck
FRONT_ACI=${DIR}/${FRONT_IMG}.aci
FRONT_RUN_OPT="--set-env=SERV_HOST=$SERV_HOST --set-env=SERVER_PORT=$SERVER_PORT --set-env=RDECK_APP_PORT=$RDECK_APP_PORT --set-env=RDECK_HOST=$RDECK_HOST --port www:$RDECK_APP_PORT"
FRONT_TRY=40
FRONT_TRY_DELAY=2
FRONT_LOG=$DIR/front.log

########################################################################################
# Functions
########################################################################################

usage () {
	echo "$0"
	echo "usage : {build|start|stop|clean|status}"
	exit 5
}

acbuildend () {
	export EXIT=$?;
	$ACBUILD --debug end
	exit $EXIT;
}

build () {
	set -e
	$ACBUILD --debug begin $IMG_ORIGINE
	trap acbuildend EXIT
	$ACBUILD --debug set-name $FRONT_IMG
	$ACBUILD --debug run -- apk update
	$ACBUILD --debug run -- apk add haproxy
	$ACBUILD --debug copy ${DIR}/startup.sh /root/startup.sh
	$ACBUILD --debug set-exec -- sh /root/startup.sh
	$ACBUILD --debug port add www tcp $RDECK_APP_PORT
	$ACBUILD --debug write --overwrite $FRONT_ACI
	trap '' EXIT
	set +e
	$ACBUILD --debug end
	sudo chown ${USER}:${GROUP} $FRONT_ACI
	sudo rkt fetch --insecure-options=image $FRONT_ACI
	sudo rkt image list | grep $FRONT_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		[ -f $FRONT_ACI ] && sudo rm -f $FRONT_ACI
	fi
}

start () {
	stop
	sudo rkt image list | grep $FRONT_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt run $FRONT_RUN_OPT $FRONT_IMG > $FRONT_LOG &
	else
		echo "File $FRONT_ACI not found"
	fi
	#NB_TRY=0
	#START=1
	#until [ $START -eq 0 -o $NB_TRY -ge $FRONT_TRY ]
	#do
	#	sleep $FRONT_TRY_DELAY
	#	NB_TRY=`expr $NB_TRY + 1`
	#	sudo grep "database system is ready to accept connections" $FRONT_LOG 2>&1 1>/dev/null
	#	[ $? -eq 0 ] && START=0
	#done
	#if [ $NB_TRY -ge $FRONT_TRY ]
	#then
	#	echo "Front ko"
	#	exit 2
	#fi
}

stop () {
	UUID=`sudo rkt list | grep $FRONT_IMG | awk '{print $1}'`
	if [ "$UUID" != "" ]
	then
		STATE=`sudo rkt list | grep $FRONT_IMG | awk '{print $4}'`
		if [ $STATE = "running" ]
		then
			sudo rkt stop --force $UUID
			sudo rkt rm $UUID
		else
			sudo rkt rm $UUID
		fi
	fi
}

clean () {
	stop
	sudo rkt image list | grep $FRONT_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		UUID_IMG=`sudo rkt image list | grep $FRONT_IMG | awk '{print $1}'`
		sudo rkt image rm $UUID_IMG
		sudo rkt image gc
	fi
	[ -f $FRONT_ACI ] && sudo rm -f $FRONT_ACI
	[ -f $FRONT_LOG ] && sudo rm -f $FRONT_LOG
}

status () {
	UUID=`sudo rkt list | grep $FRONT_IMG | awk '{print $1}'`
	if [ "$UUID" = "" ]
	then
		echo "Container not launched"
	else
		sudo rkt list | grep $FRONT_IMG
	fi
	sudo rkt image list | grep $FRONT_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt image list | grep $FRONT_IMG
	else
		echo "Image $FRONT_IMG not loaded in rkt"
	fi
}

########################################################################################
# Main
########################################################################################

if [ $# -ne 1 ]
then
	usage
fi
# {build|start|stop|clean|status}
case $1 in
	build)
		build
		;;
	start)
		start
		;;
	stop)
		stop
		;;
	clean)
		clean
		;;
	status)
		status
		;;
	*)
		usage
		;;
esac

exit 0
