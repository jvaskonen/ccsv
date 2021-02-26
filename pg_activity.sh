#!/bin/bash

while getopts "U:u:d:h:x:l:o:p:c:i" o; do
  case "${o}" in
    U) user=${OPTARG}
       ;;
    c) columns=${OPTARG}
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
    o) order_by=${OPTARG}
      ;;
    i) show_idle=1
      ;;
    *)
      cat <<EOF
Unknown option: ${o}

USAGE:
$0 [options]
Options:
  -U  The database user that should perform the activity query
  -c  The list of pg_stat_activity columns you wish to include
      in the output. You may also use 'age' and 'txn_age' to
      get the query and transation start times relative to the
      present.
  -d  Show queries running on this database
  -h  The host of the database where you wish to view activity
  -i  Show idle transactions
  -l  Limit results to the oldest <l> queries
  -o  order by column[s]
  -p  The port of the database you are connecting to
  -u  Show queries run by this user(s)
  -x  Exclude queries run by this user(s)
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
echo "$order_by" | grep -Pq '[^0-9a-z_ ,]' && echo "Order by must be alphanumeric or ," && exit
echo "$columns" | grep -Pq '[^a-z_ ,]' && echo "Columns must only contain lower case letters, underscores or ," && exit
if [ -z "${user}" ]
then
    user=postgres
fi

if [ ! -z "${db_name}" ]
then
    DB_FILTER="\n      AND datname = '$db_name'"
    DB_OPT="-d $db_name"
fi

if [ ! -z "${search_user}" ]
then
    USER_FILTER="\n      AND usename = '$search_user'"
fi

if [ ! -z "${exclude_user}" ]
then
    EXCLUDE_FILTER="\n      AND usename != '$exclude_user'"
fi

if [ -z "${show_idle}" ]
then
    IDLE_FILTER="state != 'idle'"
else
    IDLE_FILTER="state != 'never going to give you up, never going to let you down'"
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

if [ ! -z "${order_by}" ]
then
    ORDERBY=`echo -n ${order_by} | sed 's/txn_age/now()-xact_start/;s/age/now()-query_start/'`
fi

if [ -z "${columns}" ]
then
    ACTIVITY_COLUMNS="pid, datname, usename, date_trunc('milliseconds',now() - query_start) as age, query"
    # By default order by the age of the running query
    if [ -z "${ORDERBY}" ]
    then
        ORDERBY=4
    fi
else
    ACTIVITY_COLUMNS=`echo -n ${columns} | sed 's/txn_age/date_trunc('"'"milliseconds"'"',now()-xact_start) as -moop-/;s/age/date_trunc('"'"milliseconds"'"',now()-query_start) as "age"/;s/-moop-/txn_age/'`
    # If we don't have an explicit order by column, order by column 1
    # because there's sure to be one
    if [ -z "${ORDERBY}" ]
    then
        ORDERBY=1
    fi
fi

read -rd '' ACTIVITY_QUERY << __ACTIVITY_QUERY__
COPY (
  SELECT $ACTIVITY_COLUMNS
  FROM pg_stat_activity
  WHERE
      $IDLE_FILTER $DB_FILTER $USER_FILTER $EXCLUDE_FILTER
  ORDER BY $ORDERBY
  $LIMIT
) TO STDOUT WITH CSV HEADER
__ACTIVITY_QUERY__

echo -e "$ACTIVITY_QUERY" | psql -U $user $HOST_OPT $PORT_OPT $DB_OPT | ccsv.pl -hb
