# Django Management Commands

A set of management commands that that might be useful to
drop into a project to serve a periodic or occasional need.

## [migrate_model.py](management/commands/migrate_model.py)

A script to copy one database to another within a project via
the Django ORM.  It's slow, but masks database differences, such
as version, behind the ORM and also supports chunking rows to better
manage memory use.


## [affiliation_csv.py](management/commands/affiliation_csv.py)

A script that reads csv from a file or stdin that contains a
column of UW Netids or email addresses, and reflects that csv
to stdout after appending affiliation data in one of two forms:
by a single affiliation precidence column, or as individual
faculty, staff and student columns.
