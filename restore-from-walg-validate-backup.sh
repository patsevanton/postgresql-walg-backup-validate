#!/bin/bash

pg_full_version=$(psql --version | awk '{print $3}')
pg_major_version=${pg_full_version%.*}

#echo $pg_major_version

array_bucket=( $(minio-mc ls pg96| awk '{print $5}') )

#echo $array_bucket

for i in "${array_bucket[@]}"
do
    echo $i
    if [[ "$i" ==  *"pg96"* ]];
    then
        echo "bucket contain pg96 in name"
        /usr/pgsql-$pg_major_version/bin/pg_ctl stop -l logfile
        minio-mc cp --recursive pg96/"$i" "$i"
tee /var/lib/pgsql/.walg.json << END
{
   "WALG_FILE_PREFIX":"/var/lib/pgsql/$i",
   "PGDATA":"/var/lib/pgsql/$pg_major_version/data/",
   "PGHOST":"/var/run/postgresql/.s.PGSQL.5432",
   "WALG_COMPRESSION_METHOD":"brotli"
}
END
        rm -rf /var/lib/pgsql/9.6/data
        mkdir -p /var/lib/pgsql/$pg_major_version/data
        wal-g backup-fetch /var/lib/pgsql/$pg_major_version/data/ LATEST
        echo "restore_command = '/usr/local/bin/wal-g wal-fetch "%f" "%p"'" > /var/lib/pgsql/$pg_major_version/data/recovery.conf 
        /usr/pgsql-$pg_major_version/bin/pg_ctl start -l logfile

/usr/pgsql-$pg_major_version/bin/pg_ctl start -D /var/lib/postgres/data >/dev/null 2>&1
rtn=$?
if [ $rtn -ne 0 ]; then
    echo "not running"
else
    echo "ok ok"
fi
        pg_dumpall -h /var/run/postgresql >/dev/null
        /usr/pgsql-$pg_major_version/bin/pg_ctl stop -l logfile
    else
        echo "bucket dont contain pg96 in name"
    fi
done
