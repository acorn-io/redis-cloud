## Purpose

This folder defines an Acorn service which allows to create a Redis Cloud cluster. 

## Prerequisites

To use this service you need to have a Redis Cloud account and a secret api key. For convenience, we will keep those values in the following environment variables. 

- REDIS_CLOUD_ACCOUNT_KEY
- REDIS_CLOUD_SECRET_KEY

## Running the service

First we need to create the secret *redis-cloud-creds* providing the account key, secret key and subscription id.

Note: the following example uses environment variables already defined in the current shell 

```
acorn secrets create \
  --type opaque \
  --data account_key=$ACCOUNT_KEY \
  --data secret_key=$SECRET_KEY \
  redis-cloud-creds
```

Next we run the Acorn:

```
acorn run -n redis .
```

In a few tens of seconds a new Redis cluster will be up and running.

Running the service directly was just a test to ensure a cluster is actually created from this service.

Then we can delete the application, this will also delete the associated redis cluster:

```
acorn rm redis --all --force
```

## Status

This service is currently a WIP, feel free to give it a try. Feedback are welcome.