#!/bin/sh

for d in */ ; do
    echo "$d"
    cd $d
    if [ $? -eq 0 ]; then
        docker-compose down
        cd ..
    fi
done
