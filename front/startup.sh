export SERV_HOST=${SERV_HOST}
export SERVER_PORT=${SERVER_PORT}
export WWW_PORT=${WWW_PORT}
export RDECK_HOST=${RDECK_HOST}
#export CONF_FILE=/etc/nginx/conf.d/rundeck.conf
export CONF_FILE=/etc/haproxy/haproxy.cfg

#mkdir /run/nginx

#rm /etc/nginx/conf.d/default.conf

cat <<EOT > $CONF_FILE
frontend ${RDECK_HOST}
    bind 0.0.0.0:${WWW_PORT}
    default_backend bk_web

backend bk_web
    balance roundrobin
    cookie JSESSIONID prefix nocache
EOT
NB=1
for IP in `echo $SERV_HOST | awk 'BEGIN{RS=";"}{print $0}' | sed -e '/^$/d'`
do
	echo "    server s${NB} ${IP}:${SERVER_PORT} check cookie s${NB}" >> $CONF_FILE
	NB=`expr $NB + 1`
done

cat $CONF_FILE

/usr/sbin/haproxy -f $CONF_FILE
