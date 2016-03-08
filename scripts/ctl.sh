#!/bin/sh

PID=""
ERROR=0
INSTALL_PATH=/opt/bitnami/apache-solr
JAVABIN=/opt/bitnami/java/bin/java


# Apache Solr
SOLR_HOME=/opt/bitnami/apache-solr/solr
SOLR_PIDFILE=/opt/bitnami/apache-solr/bin/solr-8983.pid
SOLR_PID=""
SOLR="bin/solr start -p 8983"
SOLR_STATUS=""

SOLR_ASROOT=0
if [ `id|sed -e s/uid=//g -e s/\(.*//g` -eq 0 ]; then
    SOLR_ASROOT=1
fi

get_pid() {
    PID=""
    PIDFILE=$1
    # check for pidfile
    if [ -f $PIDFILE ] ; then
        exec 6<&0
        exec < $PIDFILE
        read pid
        PID=$pid
        exec 0<&6 6<&-
    fi
}

get_solr_pid() {
    get_pid $SOLR_PIDFILE
    if [ ! $PID ]; then
        return 
    fi
    if [ $PID -gt 0 ]; then
        SOLR_PID=$PID
    fi
}

is_service_running() {
    PID=$1
    if [ "x$PID" != "x" ] && kill -0 $PID 2>/dev/null ; then
        RUNNING=1
    else
        RUNNING=0
    fi
    return $RUNNING
}

is_solr_running() {
    get_solr_pid
    is_service_running $SOLR_PID
    RUNNING=$?
    if [ $RUNNING -eq 0 ]; then
        SOLR_STATUS="solr not running"
    else
        SOLR_STATUS="solr already running"
    fi
    return $RUNNING
}

start_solr() {
    is_solr_running
    RUNNING=$?

    if [ $RUNNING -eq 1 ]; then
        echo "$0 $ARG: solr (pid $SOLR_PID) already running"
    else
	if [ $SOLR_ASROOT -eq 1 ]; then
	    su solr -s /bin/sh -c "cd $INSTALL_PATH && $SOLR >/dev/null 2>&1 &"
	else
            cd $INSTALL_PATH
            nohup $SOLR  >/dev/null 2>&1 &  
	fi
        sleep 3
        ps ax | grep start.jar | grep solr | grep "/opt/bitnami/apache-solr" | grep -v grep | awk {'print $1'} > $SOLR_PIDFILE
        is_solr_running
        RUNNING=$?
        if [ $RUNNING -eq 0 ]; then
            ERROR=1
        fi
        if [ $ERROR -eq 0 ]; then
            echo "$0 $ARG: solr started"
            sleep 2
        else
            echo "$0 $ARG: solr could not be started"
            ERROR=3
        fi
        cd $INSTALL_PATH
    fi
}

stop_solr() {
    NO_EXIT_ON_ERROR=$1
    is_solr_running
    RUNNING=$?

    if [ $RUNNING -eq 0 ]; then
        echo "$0 $ARG: $SOLR_STATUS"
        if [ "x$NO_EXIT_ON_ERROR" != "xno_exit" ]; then
            exit
        else
            return
        fi
    fi
    get_solr_pid
    kill $SOLR_PID
    if [ $? -eq 0 ]; then
        echo "$0 $ARG: solr stopped"
    else
        echo "$0 $ARG: solr could not be stopped"
        ERROR=4
    fi
}

cleanpid() {
    rm -f $SOLR_PIDFILE
}

help() {
    echo "usage: $0 help"
    echo "       $0 (start|stop|restart) solr

help       - this screen
start      - start the service(s)
stop       - stop  the service(s)
restart    - restart or start the service(s)"
    exit 0
}

if [ "x$1" = "xstart" ]; then
    start_solr
    sleep 5

elif [ "x$1" = "xstop" ]; then
    stop_solr
    sleep 2
elif [ "x$1" = "xstatus" ]; then
    is_solr_running
    echo "$SOLR_STATUS"
elif [ "x$1" = "xcleanpid" ]; then
    cleanpid
fi

exit $ERROR
