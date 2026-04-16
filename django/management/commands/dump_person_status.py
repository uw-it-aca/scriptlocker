# Copyright 2026 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.core.management.base import BaseCommand
from restclients_core.exceptions import DataFailureException
from argparse import FileType
from uw_pws import PWS
from restclients_core.exceptions import InvalidNetID
import sys
import csv
import logging


logging.getLogger().setLevel(logging.INFO)


class Command(BaseCommand):
    help = 'dump person status of given netids to csv'

    def add_arguments(self, parser):
        parser.add_argument(
            'input_netids',
            nargs='?',
            type=FileType('r'),
            default=sys.stdin,
            help='file containing netids (default: stdin)'
        )

    def handle(self, *args, **options):
        input_netids = options['input_netids']
        csv_writer = csv.writer(sys.stdout)
        pws = PWS()

        csv_writer.writerow(['netid', 'is_faculty', 'is_staff', 'is_student'])
        for netid in input_netids:
            netid = netid.strip()
            if netid:
                try:
                    person = pws.get_person_by_netid(netid)
                    data = [netid,
                            'X' if person.is_faculty else '',
                            'X' if person.is_staff else '',
                            'X' if person.is_student else '']
                except InvalidNetID:
                    data = [netid]

                csv_writer.writerow(data)
