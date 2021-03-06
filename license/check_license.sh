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

copyright="# Copyright $(date +'%Y') UW-IT, University of Washington"
identifier="# SPDX-License-Identifier: ${license}"

find ${appdir} -type f -size +0 -not -path "*/migrations/*" -name "*.py" -exec grep -PzL "$copyright\n$identifier" {} \;
