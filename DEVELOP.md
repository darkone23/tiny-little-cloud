some commands:

[just](https://just.systems/man/en) automates some project commands

```sh
just -l
#    garage +ARGS
#    garage_assign
#    garage_create_bucket BUCKET
#    garage_create_key KEY
#    garage_create_repo NAME
#    pulumi-login
#    s3 +ARGS
#    start_local_docker_garage
```

this repo is using the s3-compatible storage tool [garage](https://garagehq.deuxfleurs.fr/) for a pulumi backend

'cloud native' version of 'local files'

```sh
# tutorial from https://garagehq.deuxfleurs.fr/documentation/quick-start/
just start_local_docker_garage
just garage_assign
just garage_create_repo "tiny-little-cloud"
just s3 ls s3://tiny-little-cloud/
```

you are also probably wanting a container registry...

this repo is included oras which is recommending a zot backend

```sh
# assuming intel hardware
just start_local_docker_zot_amd64
just zot_oras_example
just skopeo_cp
just regctl_ls
```
