#! /usr/bin/env python

import os
import sys
import ast
import json
import argparse
from uw_r25.spaces import get_spaces
from uw_r25.reservations import get_reservations
from uw_r25.events import get_events
from commonconf.backends import use_configparser_backend


use_configparser_backend(os.getenv('R25_CONFIG'), "app")


def space_payload(space):
    return {
        'space_id': space.space_id,
        'name': space.name,
        'formal_name': space.formal_name
    }


def event_payload(event):
    return {
        'event_id': event.event_id,
        'start_date': event.start_date,
        'end_date': event.end_date,
        'reservations': [reservation_payload(r) for r in event.reservations]
    }


def reservation_payload(reservation):
    return {
            'reservation_id': reservation.reservation_id,
            'state': reservation.state,
            'start_datetime': reservation.start_datetime,
            'end_datetime': reservation.end_datetime,
            'event_id': reservation.event_id,
            'event_name': reservation.event_name,
            'profile_name': reservation.profile_name,
            'contact_name': reservation.contact_name,
            'contact_email': reservation.contact_email
        }


def fetch_space(**kwargs):
    return [space_payload(space) for space in get_spaces(**kwargs)]


def fetch_events(**kwargs):
    return [event_payload(event) for event in get_events(**kwargs)]


def fetch_reservations(**kwargs):
    return [reservation_payload(r) for r in get_reservations(**kwargs)]


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('resource', help="spaces, events, or reservations")
    ap.add_argument('kwargs', help="comma delimited list of API parameters")
    args = vars(ap.parse_args())
    resource = args['resource']
    expr = ast.parse('dict({})'.format(args['kwargs']), mode="eval")
    kwargs = {kw.arg: ast.literal_eval(kw.value) for kw in expr.body.keywords}

    payload = ''
    if resource == 'spaces':
        payload = fetch_space(**kwargs)
    elif resource == 'events':
        payload = fetch_events(**kwargs)
    elif resource == 'reservations':
        payload = fetch_reservations(**kwargs)
    else:
        print("bad option: {}".format(resource), file=sys.stderr)
        print("usage: {} option argument".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)

    print(json.dumps(payload))
