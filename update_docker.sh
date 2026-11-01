#!/bin/sh

for d in */ ; do
    echo "$d"
    cd $d
    if [ $? -eq 0 ]; then
        docker-compose pull && docker-compose up -d
        cd ..
    fi
done
