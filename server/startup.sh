export RDECK_BASE=/root/rundeck
export RDECK_PORT=${RDECK_PORT:=4440}
export RDECK_HOST=${RDECK_HOST:=localhost}
export RDECK_APP_PORT=${RDECK_APP_PORT:=4440}
export DATA_HOST=${DATA_HOST:=localhost}
cd $RDECK_BASE

sed -i "s/rootfs/$RDECK_HOST/g" /root/rundeck/server/config/rundeck-config.properties
sed -i "s/4440/$RDECK_APP_PORT/g" /root/rundeck/server/config/rundeck-config.properties

sed -i "/dataSource.url/d" /root/rundeck/server/config/rundeck-config.properties

echo "dataSource.driverClassName = org.postgresql.Driver" >> /root/rundeck/server/config/rundeck-config.properties
echo "dataSource.url = jdbc:postgresql://${DATA_HOST}/rundeck" >> /root/rundeck/server/config/rundeck-config.properties
echo "dataSource.username=rundeckuser" >> /root/rundeck/server/config/rundeck-config.properties
echo "dataSource.password=rundeckpassword" >> /root/rundeck/server/config/rundeck-config.properties

java -Xmx1024m -Xms256m -server -Dserver.http.port=$RDECK_PORT -jar rundeck-launcher.jar --skipinstall
