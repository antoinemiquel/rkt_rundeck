#!/usr/bin/env bash

########################################################################################
# Variables
########################################################################################

DIR=`pwd`
USER=`id -u`
GROUP=`id -g`

. $DIR/server.env

PROJECT_DATA=$DIR/projects

RUNDECK_IMG=rundeck_server
RUNDECK_ACI=${DIR}/${RUNDECK_IMG}.aci
RUNDECK_RUN_OPT="--volume projectsdir,kind=host,source=$PROJECT_DATA --set-env=RDECK_PORT=$RDECK_PORT --set-env=RDECK_HOST=$RDECK_HOST --set-env=RDECK_APP_PORT=$RDECK_APP_PORT --set-env=DATA_HOST=$DATA_HOST"
RUNDECK_TRY=80
RUNDECK_TRY_DELAY=4
RUNDECK_LOG=$DIR/rundeck$$.log

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
	$ACBUILD --debug set-name $RUNDECK_IMG
	$ACBUILD --debug run -- apk update
	$ACBUILD --debug run -- apk add openjdk8-jre
	$ACBUILD --debug run -- apk add java-postgresql-jdbc
	$ACBUILD --debug run -- mkdir -p /root/rundeck
	$ACBUILD --debug run -- wget $RUNDECK_JAR_ADDR -O /root/rundeck/rundeck-launcher.jar
	$ACBUILD --debug run -- java -jar /root/rundeck/rundeck-launcher.jar --installonly
	$ACBUILD --debug run -- ln -s /usr/share/java/postgresql-jdbc.jar /root/rundeck/server/lib/postgresql-jdbc.jar
	$ACBUILD --debug copy ${DIR}/startup.sh /root/startup.sh
	$ACBUILD --debug set-exec -- sh /root/startup.sh
	$ACBUILD --debug mount add projectsdir /root/rundeck/projects
	$ACBUILD --debug port add rdk tcp $RDECK_PORT
	$ACBUILD --debug write --overwrite $RUNDECK_ACI
	trap '' EXIT
	set +e
	$ACBUILD --debug end
	sudo chown ${USER}:${GROUP} $RUNDECK_ACI
	sudo rkt fetch --insecure-options=image $RUNDECK_ACI
	sudo rkt image list | grep $RUNDECK_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		[ -f $RUNDECK_ACI ] && sudo rm -f $RUNDECK_ACI
	fi
	if [ ! -d $PROJECT_DATA ]
	then
		echo "Create projects dir"
		reset_data
	fi
}

reset_data () {
	stop
	if [ ! -d $PROJECT_DATA ]
	then
		mkdir -p $PROJECT_DATA
	else
		sudo rm -rf $PROJECT_DATA
		mkdir -p $PROJECT_DATA
	fi
}

start () {
	sudo rkt image list | grep $RUNDECK_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		sudo rkt run $RUNDECK_RUN_OPT $RUNDECK_IMG > $RUNDECK_LOG &
	else
		echo "File $RUNDECK_IMG not found"
		exit 2
	fi
	NB_TRY=0
	START=1
	until [ $START -eq 0 -o $NB_TRY -ge $RUNDECK_TRY ]
	do
		sleep $RUNDECK_TRY_DELAY
		NB_TRY=`expr $NB_TRY + 1`
		sudo grep "Started ServerConnector" $RUNDECK_LOG 2>&1 1>/dev/null
		[ $? -eq 0 ] && START=0
	done
	if [ $NB_TRY -ge $RUNDECK_TRY ]
	then
		echo "Server ko"
		exit 2
	fi
}

stop () {
	for UUID in `sudo rkt list | grep $RUNDECK_IMG | awk '{print $1}'`
	do
		if [ "$UUID" != "" ]
		then
			STATE=`sudo rkt list | grep $UUID | awk '{print $4}'`
			if [ $STATE = "running" ]
			then
				sudo rkt stop --force $UUID
				sudo rkt rm $UUID
			else
				sudo rkt rm $UUID
			fi
		fi
	done
}

clean () {
	stop
	sudo rkt image list | grep $RUNDECK_IMG 2>&1 1>/dev/null
	if [ $? -eq 0 ]
	then
		UUID_IMG=`sudo rkt image list | grep $RUNDECK_IMG | awk '{print $1}'`
		sudo rkt image rm $UUID_IMG
		sudo rkt image gc
	fi
	[ -f $RUNDECK_ACI ] && sudo rm -f $RUNDECK_ACI
	find . -name "*.log" -exec rm -f {} \;
}

clean_data () {
	if [ -d $PROJECT_DATA ]
	then
		sudo rm -rf $PROJECT_DATA
	fi
}

status () {
	for UUID in `sudo rkt list | grep $RUNDECK_IMG | awk '{print $1}'`
	do
		if [ "$UUID" = "" ]
		then
			echo "Container not launched"
		else
			sudo rkt list | grep $UUID
		fi
		sudo rkt image list | grep $RUNDECK_IMG 2>&1 1>/dev/null
		if [ $? -eq 0 ]
		then
			sudo rkt image list | grep $RUNDECK_IMG
		else
			echo "Image $RUNDECK_IMG not loaded in rkt"
		fi
	done
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
