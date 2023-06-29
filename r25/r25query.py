#! /usr/bin/env python

import os
import sys
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


def fetch_space(space_name):
    spaces = get_spaces(contains=space_name)
    space_data = []
    for space in spaces:
        space_data.append(space_payload(space))

    return space_data


def event_fetch(**kwargs):
    events = get_events(**kwargs)
    event_data = []
    for event in events:
        event_data.append(event_payload(event))

    return event_data


def fetch_events(space_id):
    return event_fetch(space_id=space_id)


def fetch_event(event_id):
    return event_fetch(event_id=event_id)


def fetch_reservations(event_id):
    reservations = get_reservations(event_id=event_id)
    reservation_data = []
    for reservation in reservations:
        reservation_data.append(reservation_payload(reservation))

    return reservation_data


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('resource', help="spaces, events, event, or reservations")
    ap.add_argument('param', help="space name, event id, or reservation id")
    args = vars(ap.parse_args())
    payload = ''
    resource = args['resource']
    param = args['param']

    if resource == 'spaces':
        payload = fetch_space(param)
    elif resource == 'events':
        payload = fetch_events(param)
    elif resource == 'event':
        payload = fetch_event(param)
    elif resource == 'reservations':
        payload = fetch_reservations(param)
    else:
        print("bad option: {}".format(resource), file=sys.stderr)
        print("usage: {} option argument".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)

    print(json.dumps(payload))
