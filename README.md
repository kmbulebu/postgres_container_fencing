# Postgres Container Fencing
A script for preventing more than one Postgres container from concurrently using the same data.

## Problem Statement
In an orchestrated environment, such as Docker Swarm, it possible for more than one instance of the Postgres container to be instantiated. If the container's share storage, such as the case with a named volume backed by NFS, the multiple Postgres instance could corrupt the database. 

A possible scenario where Docker Swarm might instantiate multiple instances of the Postgres container is during a swarm node split-brain. If the host node running the Postgres database is a Swarm manager and loses network connectivity, the remaining members of the Swarm will reach quorum without it. Those members will schedule a new task of the Postgres service, resulting in two containers of Postgres, unaware of eachother. If those containers are sharing the same storage, data corruption is likely. Hopefully new orchestrations features can prevent this scenario. 

## How it works
A lock file is placed in the Postgres directory when the database starts. If that lock file already exists, and the contents do not match the current container instance, the fencing script will exit, stopping the container. By default, the hostname of the container, which Docker defaults to the container ID, is used as the fencing token. Only a container with that hostname will be able to start as long as the file exists.

## Environment Variables
`FENCE_VARIABLE` Default Value: `$HOSTNAME` The expression (environment variable) that will be used to enforce fencing.

`FENCE_LOCK_FILE` Default Value: `/var/lib/postgresql/data/fence_lock` Sets the absolute path of the fencing lockfile.

## Expected Fencing Behavior
If no existing lockfile, start postgres.

If existing lockfile and contents do not match `FENCE_VARIABLE` expression, exits with non-zero return code.

If existing lockfile and contents match `FENCE_VARIABLE` expression, starts postgres.

## Recovering from killed container
If the container is forcefully killed, the lockfile will remain. This is the desired behavior and requires manual intervention. After ensuring no instances of Postgres are running, remove the `$FENCE_LOCK_FILE`.

## Using with compose or stacks
In this example, we use the new configs file feature to inject the script, and place it at the front of the path to ensure it's called instead of postgres.

```configs:
  postgres_fence:
    file: ./configs/fence.sh

  postgresql:
    image: postgres:9.6.3-alpine
    configs:
      - source: postgres_fence
        target:  /newbin/postgres
        mode: 0555
    environment:
      PATH: '/newbin:$PATH'
```

## Using with Dockerfile
In this example, we build a new image with our fencing script and place it at the front of the path to ensure it's called instead of postgres.
```
FROM postgres:9.6.3-alpine

COPY fence.sh /newbin/postgres
ENV PATH /newbin/:$PATH
```

## Input Welcome!
Tips, suggestions, and fixes welcome! Please submit an issue or pull request with your ideas. 
