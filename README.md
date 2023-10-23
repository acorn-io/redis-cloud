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

The [examples folder](https://github.com/acorn-io/redis/tree/main/examples) contains a sample application using this Service. This app consists in a Python backend based on the FastAPI library, it displays a web page indicating the number of times the application was called, a counter is saved in the underlying Redis database and incremented with each request. The screenshot below shows the UI of the example application. 

![UI](./images/ui.png)

To use the Redis Service, we first define a *service* property in the Acornfile of the application:

```
services: db: {
  image: "ghcr.io/acorn-io/redis:v#.#.#-#"
}
```

Next we define the application container:

```
containers: app: {
	build: {
		context: "."
		target:  "dev"
	}
	consumes: ["db"]
	ports: publish: "8000/http"
	env: {
		REDIS_HOST: "@{service.db.address}"
		REDIS_PASS: "@{service.db.secrets.admin.token}"
	}
}
```

This container is built using the Dockerfile in the examples folder. Once built, the container consumes the Redis service using the address and admin password provided through dedicated variables:
- @{service.db.address}
- @{service.db.secrets.admin.token}

This example can be run with the following command (to be run from the *examples* folder)

```
acorn run -n app
```

After a few tens of seconds an http endpoint will be returned. Using this endpoint we can access the application and see the counter incremented on each reload of the page.


## Deploy the app to your Acorn Sandbox

Instead of managing your own Acorn installation, you can deploy this application in the Acorn Sandbox, the free SaaS offering provided by Acorn. Access to the sandbox requires only a GitHub account, which is used for authentication.

[![Run in Acorn](https://beta.acorn.io/v1-ui/run/badge?image=ghcr.io+acorn-io+redis-cloud+examples:v%23.%23-%23)](https://beta.acorn.io/run/ghcr.io/acorn-io/redis-cloud/examples:v%23.%23-%23)

An application running in the Sandbox will automatically shut down after 2 hours, but you can use the Acorn Pro plan to remove the time limit and gain additional functionalities.