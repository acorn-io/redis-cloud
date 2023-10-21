--- WIP ---  
Not fully functional yet

## Redis database

Redis is an in-memory data store, used as a database, cache, and message broker. It supports various data structures such as strings, hashes, lists, sets, and more, offering high performance and wide-ranging versatility. More information on [https://redis.io](https://redis.io/).

## Redis Cloud as an Acorn Service

The Acornfile used to create a Redis Cloud Acorn Service is available in the GitHub repository at [https://github.com/lucj/acorn-redis-cloud](https://github.com/lucj/acorn-redis-cloud). This service triggers the creation of a Redis Cloud database which can easily be used by an application in different stages.

This Redis Cloud instance:
- creates a fixed subscription
- creates a Standard 30MB database type in *AWS* / *us-east-1* region

The Acorn image of this service is hosted in GitHub container registry at [ghcr.io/lucj/acorn-redis-cloud](ghcr.io/lucj/acorn-redis-cloud). 

## Prerequisites

To use this service you need to have a Redis Cloud account and a secret api key. For convenience, we will keep those values in the following environment variables. 

- REDIS_CLOUD_ACCOUNT_KEY
- REDIS_CLOUD_SECRET_KEY

Next we need to create the secret *redis-cloud-creds* providing the account key, secret key and subscription id.

```
acorn secrets create \
  --type opaque \
  --data account_key=$ACCOUNT_KEY \
  --data secret_key=$SECRET_KEY \
  redis-cloud-creds
```

## Usage

Example to be added soon