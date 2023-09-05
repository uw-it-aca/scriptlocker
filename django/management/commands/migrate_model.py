# Copyright 2023 UW-IT, University of Washington
# SPDX-License-Identifier: Apache-2.0

from django.core.management.base import BaseCommand
from django.core import serializers
from django.apps import apps
import sys
import logging

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "migrate a table from source to destination db by row groups"

    def add_arguments(self, parser):

        parser.add_argument(
            '-r','--rows', type=int, default=1000,
            help="row count per  to update")
        parser.add_argument(
            'model', type=str,
            help="Specified as app_label.ModelName")
        parser.add_argument(
            'source_database', type=str,
            help="Source Database name")
        parser.add_argument(
            'destination_database', type=str,
            help="Destination database name")


    def handle(self, *args, **options):
        self.verbosity = options['verbosity']
        row_count = options['rows']
        src_db = options['source_database']
        dest_db = options['destination_database']
        app_name, model_name = tuple(options['model'].split('.'))
        Model = apps.get_model(app_label=app_name, model_name=model_name)

        self.migrate_model(Model, src_db, dest_db, rows=row_count)


    def migrate_model(self, model, src_db, dest_db, rows=500, start=0):
        count = model.objects.using(src_db).count()
        self.verbose(
            1, "Migrate {} ({} rows, chunked by {} rows) from {} to {}".format(
                model.__name__, count, rows, src_db, dest_db))

        for i in range(start, count, rows):
            src_data = model.objects.using(src_db).all()[i:i+rows]

            if self.verbosity >= 1:
                pct, pct_dec = str((100*(i+len(src_data)))/count).split('.')
                self.verbose(
                    1, '\r{}/{} ({}.{} %)'.format(
                        i + rows, count, pct, pct_dec[:2]),
                    newline=False)

            src_data_json = serializers.serialize("json", src_data)
            dest_data = serializers.deserialize(
                "json", src_data_json, using=dest_db)

            for n in dest_data:
                n.save(using=dest_db)

        self.verbose(1, "Done")


    def verbose(self, level, message, newline=True):
        if level <= self.verbosity:
            print(message, end="\n" if newline else "")
            sys.stdout.flush()
