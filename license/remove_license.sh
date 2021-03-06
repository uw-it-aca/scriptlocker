#!/bin/sh

usage() { echo "Usage: $0 -d <app directory> [-l <license>]" 1>&2; exit 1; }

license="Apache-2.0"
while getopts hd:l: flag
do
    case "${flag}" in
        h) usage;;
        d) appdir=${OPTARG};;
        l) license=${OPTARG};;
    esac
done

if [ -z "${appdir}" ]; then
    usage
fi

copyright="# Copyright 202\d UW-IT, University of Washington"
identifier="# SPDX-License-Identifier: ${license}"
export copyright
export identifier

for i in $(find ${appdir} -type f -size +0 -name "*.py" -exec grep -Pzl "$copyright\n$identifier" {} \;);
do
    perl -pi -e 'BEGIN{undef $/;} s/$ENV{copyright}\n$ENV{identifier}\n\n//smg' $i
    echo "$i"
done
