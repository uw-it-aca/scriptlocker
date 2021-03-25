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

find ${appdir} -type f -size +0 -name "*.py" -exec grep -PzL "\
# Copyright $(date +'%Y') UW-IT, University of Washington\n\
# SPDX-License-Identifier: ${license}" {} \;
