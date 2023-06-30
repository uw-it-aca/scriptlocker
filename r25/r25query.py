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
        'reservations': event.reservations
    }


def reservation_payload(reservation):
    return {
        'reservation_id': reservation.reservation_id,
        'state': reservation.state,
        'start_datetime': reservation.start_datetime,
        'end_datetime': reservation.end_datetime,
        'event_id': reservation.event_id,
        'event_name': reservation.event_name,
        'formal_name': space.formal_name
    }


def fetch_space(**kwargs):
    spaces = get_spaces(**kwargs)
    space_data = []
    for space in spaces:
        space_data.append(space_payload(space))

    return space_data


def fetch_events(**kwargs):
# add Expand
    events = get_events(**kwargs)
    event_data = []
    for event in events:
        event_data.append(event_payload(event))

    return event_data


def fetch_reservations(**kwargs):
    reservations = get_reservations(**kwargs)
    reservation_data = []
    for reservation in reservations:
        reservation_data.append(reservation_payload(reservation))

    return reservation_data


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
