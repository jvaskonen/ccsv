#!/bin/bash

while getopts "U:u:d:h:x:l:p:" o; do
  case "${o}" in
    U) user=${OPTARG}
       ;;
    u) search_user=${OPTARG}
       ;;
    x) exclude_user=${OPTARG}
       ;;
    h)
      hostname=${OPTARG}
      ;;
    d)
      db_name=${OPTARG}
      ;;
    l) limit=${OPTARG}
      ;;
    p) port=${OPTARG}
      ;;
    *)
      cat <<EOF
Unknown option: ${o}

USAGE:
$0 [options]
Options:
  -U  The database user that should perform the activity query
  -h  The host of the database where you wish to view activity
  -p  The port of the database you are connecting to
  -u  Show queries run by this user(s)
  -x  Exclude queries run by this user(s)
  -d  Show queries running on this database
  -l  Limit results to the oldest <l> queries
EOF
      exit 1;
      ;;
  esac
done

echo "$db_name" | grep -Pq '[^\w\d,]' && echo "Database name(s) must be alphanumeric or ," && exit
echo "$search_user" | grep -Pq '[^\w\d,]' && echo "Search user(s) must be alphanumeric or ," && exit
echo "$exclude_user" | grep -Pq '[^\w\d,]' && echo "Exclude user(s) must be alphanumeric or ," && exit
echo "$limit" | grep -Pq '[^0-9]' && echo "Row limit must be numeric" && exit
echo "$port" | grep -Pq '[^0-9]' && echo "Port must be numeric" && exit

if [ -z "${user}" ]
then
    user=postgres
fi

if [ ! -z "${db_name}" ]
then
    DB_FILTER="AND datname = '$db_name'"
    DB_OPT="-d $db_name"
fi

if [ ! -z "${search_user}" ]
then
    USER_FILTER="AND usename = '$search_user'"
fi

if [ ! -z "${exclude_user}" ]
then
    EXCLUDE_FILTER="AND usename != '$exclude_user'"
fi

if [ ! -z "${limit}" ]
then
    LIMIT="LIMIT ${limit}"
fi

if [ ! -z "${hostname}" ]
then
   HOST_OPT="-h $hostname"
fi

if [ ! -z "${port}" ]
then
   PORT_OPT="-p $port"
fi

read -rd '' ACTIVITY_QUERY << __ACTIVITY_QUERY__
COPY (
  SELECT pid, datname, usename, now() - query_start as age, query
  FROM pg_stat_activity
  WHERE state != 'idle'
        $DB_FILTER $USER_FILTER $EXCLUDE_FILTER
  ORDER BY 4 DESC
  $LIMIT
) TO STDOUT WITH CSV HEADER
__ACTIVITY_QUERY__

echo -e "$ACTIVITY_QUERY" | psql -U $user $HOST_OPT $PORT_OPT $DB_OPT | ccsv.pl -hb
