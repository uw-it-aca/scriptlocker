# r25query.py
Script to interactively query r25Live Webservices API,
and demonstrate uw-restclient-r25 usage.

## Dependencies
```
pip install uw-restclient-r25, commonconf
```
## Configuration
```
[app]
RESTCLIENTS_CA_BUNDLE = <path_to_certs_for_host_validation>
RESTCLIENTS_R25_DAO_CLASS = Live
RESTCLIENTS_R25_INSTANCE = <webservices_instance>
RESTCLIENTS_R25_SSL_VERSION = TLSv1_2
RESTCLIENTS_R25_BASIC_AUTH = <basic_auth_token>
RESTCLIENTS_R25_HOST = https://webservices.collegenet.com
```

## Environment Variables
```
export R25_CONFIG=<path_to_configuration_file>
```

## Usage
```
./r25query [-h] <resource_name> <parameter_list>
```
Where `<resource_name>` is the API resource endpoint `spaces`,
`events` or `registrations`, and `<parameter_list>` is passed
to the provided endpoint's restclient call as keyword arguments.

Example commands might include:
```
./r25query.py spaces "contains='engineering'"
./r25query.py events "space_id=12340,start_dt='20230717',end_dt='20230717',scope='extended',include='spaces'"
./r25query.py reservations "reservation_id='12345678'"
```
