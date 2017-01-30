export RESET_DATA=${RESET_DATA:=NO}
export DATA=${DATA:=data}
export PGDATA=/${DATA}
export PGPORT=$PGPORT

export BDD_TRY=20
export BDD_TRY_DELAY=1

chown -R postgres:postgres $PGDATA
chmod 1777 -R /tmp

if [ $RESET_DATA = "YES" ]
then
	echo "reset_data, PGDATA=$PGDATA"
	rm -rf $PGDATA/*
	su - postgres -c "PGDATA=$PGDATA initdb"
	su - postgres -c "PGDATA=$PGDATA echo \"listen_addresses = '*'\" >> $PGDATA/postgresql.conf"
	su - postgres -c "PGPORT=$PGPORT PGDATA=$PGDATA echo \"port = $PGPORT\" >> $PGDATA/postgresql.conf"
	su - postgres -c "PGDATA=$PGDATA mkdir $PGDATA/pg_log"
	su - postgres -c "echo \"host rundeck rundeckuser 172.16.28.0/24 md5\" >> $PGDATA/pg_hba.conf"
	su - postgres -c "PGDATA=$PGDATA BDD_LOG=$BDD_LOG pg_ctl start -l $PGDATA/pg_log/pg.log"
	NB_TRY=0
	START=1
	until [ $START -eq 0 -o $NB_TRY -ge $BDD_TRY ]
	do
		sleep $BDD_TRY_DELAY
		NB_TRY=`expr $NB_TRY + 1`
		su - postgres -c "grep \"database system is ready to accept connections\" $PGDATA/pg_log/pg.log 2>&1 1>/dev/null"
		[ $? -eq 0 ] && START=0
	done
	echo "Create rundeck database"
	su - postgres -c "PGDATA=$PGDATA psql -c 'create database rundeck;'"
	echo "Create user rundeckuser"
	su - postgres -c "PGDATA=$PGDATA psql -c \"create user rundeckuser with password 'rundeckpassword';\""
	echo "Grant user rundeckuser on rundeck database"
	su - postgres -c "PGDATA=$PGDATA psql -c 'grant ALL privileges on database rundeck to rundeckuser;'"
	echo "Stop database"
	su - postgres -c "PGDATA=$PGDATA pg_ctl stop"
else
	echo "start"
	su - postgres -c "PGDATA=$PGDATA pg_ctl start"
	while [ 1 ]; do sleep 1;done
fi
