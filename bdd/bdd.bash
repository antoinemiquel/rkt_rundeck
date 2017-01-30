#!/usr/bin/env bash

########################################################################################
# Variables
########################################################################################

DIR=`pwd`
USER=`id -u`
GROUP=`id -g`

. $DIR/bdd.env

BDD_DATA=$DIR/$DATA
BDD_IMG=rundeck_bdd
BDD_ACI=${DIR}/${BDD_IMG}.aci
#BDD_RUN_OPT="--volume datadir,kind=host,source=$BDD_DATA --set-env=PGPORT=$PGPORT --set-env=DATA=$DATA --set-env=RESET_DATA=$RESET_DATA --port ssh:1022 --port pg:$PGPORT"
BDD_RUN_OPT="--volume datadir,kind=host,source=$BDD_DATA --set-env=PGPORT=$PGPORT --set-env=DATA=$DATA --set-env=RESET_DATA=$RESET_DATA"
BDD_TRY=40
BDD_TRY_DELAY=2
BDD_LOG=$DIR/bdd.log

########################################################################################
# Functions
########################################################################################

usage () {
	echo "$0"
	echo "usage : {build|reset_data|start|stop|clean|clean_data|status}"
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
	$ACBUILD --debug set-name $BDD_IMG
	$ACBUILD --debug run -- apk update
	$ACBUILD --debug run -- apk add postgresql
	$ACBUILD --debug copy ${DIR}/startup.sh /root/startup.sh
	$ACBUILD --debug set-exec -- sh /root/startup.sh
	$ACBUILD --debug mount add datadir /$DATA
	$ACBUILD --debug port add pg tcp $PGPORT
	$ACBUILD --debug write --overwrite $BDD_ACI
	trap '' EXIT
	set +e
	$ACBUILD --debug end
	sudo chown ${USER}:${GROUP} $BDD_ACI
	sudo rkt fetch --insecure-options=image $BDD_ACI
	sudo rkt image list | grep $BDD_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		[ -f $BDD_ACI ] && sudo rm -f $BDD_ACI
	fi
	if [ ! -d $BDD_DATA ]
	then
		echo "Create database"
		reset_data
	fi
}

reset_data () {
	stop
	RESET_DATA=YES
	if [ ! -d $BDD_DATA ]
	then
		mkdir -p $BDD_DATA
	else
		sudo rm -rf $BDD_DATA
		mkdir -p $BDD_DATA
	fi
	BDD_RUN_OPT="--volume datadir,kind=host,source=$BDD_DATA --set-env=PGPORT=$PGPORT --set-env=DATA=$DATA --set-env=RESET_DATA=$RESET_DATA --port pg:$PGPORT"
	sudo rkt image list | grep $BDD_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt run $BDD_RUN_OPT $BDD_IMG
	else
		echo "File $BDD_IMG not found"
	fi
	stop
}

start () {
	stop
	sudo rkt image list | grep $BDD_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt run $BDD_RUN_OPT $BDD_IMG > $BDD_LOG &
	else
		echo "File $BDD_ACI not found"
	fi
	NB_TRY=0
	START=1
	until [ $START -eq 0 -o $NB_TRY -ge $BDD_TRY ]
	do
		sleep $BDD_TRY_DELAY
		NB_TRY=`expr $NB_TRY + 1`
		sudo grep "database system is ready to accept connections" $BDD_LOG 2>&1 1>/dev/null
		[ $? -eq 0 ] && START=0
	done
	if [ $NB_TRY -ge $BDD_TRY ]
	then
		echo "Bdd ko"
		exit 2
	fi
}

stop () {
	UUID=`sudo rkt list | grep $BDD_IMG | awk '{print $1}'`
	if [ "$UUID" != "" ]
	then
		STATE=`sudo rkt list | grep $BDD_IMG | awk '{print $4}'`
		if [ "$STATE" = "running" ]
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
	sudo rkt image list | grep $BDD_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		UUID_IMG=`sudo rkt image list | grep $BDD_IMG | awk '{print $1}'`
		sudo rkt image rm $UUID_IMG
		sudo rkt image gc
	fi
	[ -f $BDD_ACI ] && sudo rm -f $BDD_ACI
	[ -f $BDD_LOG ] && sudo rm -f $BDD_LOG
}

clean_data () {
	if [ -d $BDD_DATA ]
	then
		sudo rm -rf $BDD_DATA
	fi
}

status () {
	UUID=`sudo rkt list | grep $BDD_IMG | awk '{print $1}'`
	if [ "$UUID" = "" ]
	then
		echo "Container not launched"
	else
		sudo rkt list | grep $BDD_IMG
	fi
	sudo rkt image list | grep $BDD_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt image list | grep $BDD_IMG
	else
		echo "Image $BDD_IMG not loaded in rkt"
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
	reset_data)
		reset_data
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
	clean_data)
		clean_data
		;;
	status)
		status
		;;
	*)
		usage
		;;
esac

exit 0
