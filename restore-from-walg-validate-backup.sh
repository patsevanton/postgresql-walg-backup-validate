#!/bin/bash

pg_full_version=$(psql --version | awk '{print $3}')
pg_major_version=${pg_full_version%.*}

#echo $pg_major_version

array_bucket=($(minio-mc ls pg96 | awk '{print $5}'))

#echo $array_bucket

for i in "${array_bucket[@]}"; do
    echo $i
    if [[ $i == *"pg96"* ]]; then
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
        rm -rf /var/lib/pgsql/$pg_major_version/data
        mkdir -p /var/lib/pgsql/$pg_major_version/data
        wal-g backup-fetch /var/lib/pgsql/$pg_major_version/data/ LATEST
        # in postgres 12+ recovery.conf is absent all parameters in main config file
        if [ $(echo "${pg_major_version} < 12" | bc) -eq 1 ]; then
            echo "restore_command = '/usr/local/bin/wal-g wal-fetch "%f" "%p"'" > /var/lib/pgsql/$pg_major_version/data/recovery.conf
        else
            echo "restore_command = '/usr/local/bin/wal-g wal-fetch "%f" "%p"'" > /var/lib/pgsql/$pg_major_version/data/postgresql.auto.conf
            touch /var/lib/pgsql/$pg_major_version/data/recovery.signal
        fi
        /usr/pgsql-$pg_major_version/bin/pg_ctl start -D /var/lib/pgsql/$pg_major_version/data > /dev/null 2>&1
        rtn=$?
        if [ $rtn -ne 0 ]; then
            echo "Postgres didn't start"
        else
            echo "Postgres start, will start pg_dumpall"
            pg_dumpall -h /var/run/postgresql > /dev/null
        fi
        /usr/pgsql-$pg_major_version/bin/pg_ctl stop -l logfile
    else
        echo "Segment name doesn't contain pg96"
    fi
done
