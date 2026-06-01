# Copyright 2026 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.core.management.base import BaseCommand
from restclients_core.exceptions import DataFailureException
from argparse import FileType
from uw_pws import PWS
from restclients_core.exceptions import InvalidNetID
import re
import sys
import csv
import logging


logging.getLogger().setLevel(logging.INFO)


class Command(BaseCommand):
    help = 'read csv of netids and appending affiliation column(s) to output'
    pws = PWS()

    def add_arguments(self, parser):
        parser.add_argument(
            '--netid-column',
            type=int,
            default=0,
            help='Index of the column containing netid (default: 0)'
        )

        parser.add_argument(
            '--individual-affiliations',
            action='store_true',
            help='Output separate column for each affiliation type'
        )

        parser.add_argument(
            'input_csv',
            nargs='?',
            type=FileType('r'),
            default=sys.stdin,
            help='csv file containing netids (default: stdin)'
        )

    def handle(self, *args, **options):
        self.individual_affiliations = options['individual_affiliations']
        netid_column = options['netid_column']
        input_csv = options['input_csv']
        csv_rows = csv.reader(input_csv)
        csv_writer = csv.writer(sys.stdout)

        header = True
        for row in csv_rows:
            if header:
                affiliation = self._affiliation_header()
                header = False
            else:
                try:
                    netid = self._uw_netid(row[netid_column])
                    affiliation = self._affiliation(netid)
                except InvalidNetID:
                    affiliation = self._no_affiliation()
                except DataFailureException as ex:
                    if ex.status == 404:
                        affiliation = self._no_affiliation()
                    else:
                        raise ex

            csv_writer.writerow(row + affiliation)

    def _uw_netid(self, email):
        try:
            local, domain = email.split('@')
            if re.match(r"(uw|washington|u\.washington)\.edu", domain):
                return local

            raise InvalidNetID(f"{email}: Not a UW email")
        except ValueError:
            return email

    def _affiliation(self, netid):
        person = self.pws.get_person_by_netid(netid)
        return self._individual_affiliations(person) if (
            self.individual_affiliations) else self._primary_affiliation(person)

    def _individual_affiliations(self, person):
        return ['X' if person.is_faculty else '',
                'X' if person.is_staff else '',
                'X' if person.is_student else '']

    def _primary_affiliation(self, person):
        return [ 'employee' if (
            person.is_faculty or person.is_staff) else 'student' if (
                person.is_student) else 'other']

    def _affiliation_header(self):
        return ['Faculty', 'Staff', 'Student'] if (
            self.individual_affiliations) else ['Primary Affiliation']

    def _no_affiliation(self):
        return ['', '', ''] if self.individual_affiliations else ['other']
