# just: https://just.systems/man/en/
# 
# explicitly set tmpdir for better shell suport https://github.com/casey/just/discussions/1269
set tempdir := "/tmp"

# some docker containers
export ZOT_HOST := 'localhost:5000'
export GARAGE_HOST := 'localhost:3900'

# local credential file for garage s3
export GARAGE_AUTH_FILE := env_var("HOME") / ".garage/credentials"

# s5client is leveraging some AWS env vars
#   https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
# 
export AWS_ENDPOINT_URL := 'http://' + GARAGE_HOST
export AWS_SHARED_CREDENTIALS_FILE := GARAGE_AUTH_FILE
export AWS_DEFAULT_REGION := 'garage'
export AWS_PROFILE := 'garage'
export AWS_ACCESS_KEY_ID := shell('test -f $1 && nu -c "open $1 | from toml | get garage.aws_access_key_id" || echo ""', GARAGE_AUTH_FILE)
export AWS_SECRET_KEY_ID := shell('test -f $1 && nu -c "open $1 | from toml | get garage.aws_secret_access_key" || echo ""', GARAGE_AUTH_FILE)

# auth is expecting two files to exist locally:
# ~/.ssh/id_ed25519 and ~/.ssh/id_ed25519.pub
export SSH_PRIVATE_KEYFILE := env_var("HOME") / ".ssh/id_ed25519"
export SSH_PUBLIC_KEYFILE := env_var("HOME") / ".ssh/id_ed25519.pub"
export SSH_PUBKEY := shell('cat $1 || echo ""', SSH_PUBLIC_KEYFILE)

# configure some utilities for pulumi
#   use ssh private key as ansible and pulumi secret-passphrase
export PULUMI_BACKEND_URL := shell('echo "s3://${1}?endpoint=${2}&disableSSL=true&s3ForcePathStyle=true"', "tiny-little-cloud", GARAGE_HOST)
export PULUMI_CONFIG_PASSPHRASE := shell('test -f $1 && ssh-to-age -private-key -i $1 -o - || echo ""', SSH_PRIVATE_KEYFILE)
export ANSIBLE_VAULT_PASSWORD_FILE := "./vault/password.sh"

hcloudrun +ARGS: 
    #!/usr/bin/env bash
    
    export HCLOUD_TOKEN=$(just echo-hcloud-token)
    exec hcloud {{ ARGS }}

packerrun +ARGS: 
    #!/usr/bin/env bash
    export HCLOUD_TOKEN=$(just echo-hcloud-token)
    export PACKER_PROJECT="hetzner-nixos-amd64"
    cd ./dreamcloud/packerbuild/${PACKER_PROJECT}
    exec packer {{ ARGS }} main.pkr.hcl

pulumirun +ARGS:
    #!/usr/bin/env bash
    
    set -ex

    cd ./dreamcloud
    exec pulumi {{ ARGS }}

pulumi-login:
    # https://www.pulumi.com/docs/iac/cli/environment-variables/
    just pulumirun login

pulumi-stack-init STACK="lab":
    just pulumirun stack init -s {{ STACK }} --secrets-provider=passphrase
    

s3 +ARGS:
    #!/usr/bin/env bash

    # set -euxo
    #
    env | grep AWS

    exec s5cmd --endpoint-url=$AWS_ENDPOINT_URL {{ ARGS }}

garage +ARGS:
    #!/usr/bin/env bash

    set -euxo pipefail

    CONTAINER="$(docker ps | awk '/dxflrs/ { print $1 }')"

    function garage() {
        docker exec -ti ${CONTAINER} /garage {{ ARGS }} 
    }

    garage

garage_assign:
    #!/usr/bin/env bash

    set -euxo pipefail
    
    NODE_ID="$(just garage status | awk '/NO ROLE/ { print $1 }')"

    just garage layout assign -z dc1 -c 1G $NODE_ID
    just garage layout apply --version 1

garage_create_bucket BUCKET:
    just garage bucket create {{ BUCKET }}
    just garage bucket list
    just garage bucket info {{ BUCKET }}

garage_aws_keymagic KEY:
    #!/usr/bin/env bash

    set -euxo pipefail

    KEYFILE=$(mktemp)
    just garage key create {{ KEY }} | strings > $KEYFILE

    KEY_ID="$(awk '/Key ID/ { print $NF }' $KEYFILE)"
    KEY_SECRET="$(awk '/Secret key/ { print $NF }' $KEYFILE)"

    mkdir -p ~/.aws
    touch {{ GARAGE_AUTH_FILE }}
    chmod 600 {{ GARAGE_AUTH_FILE }}

    # TODO: need to strip this entry from toml before writing...
    # does not support 'update'
    # 
    # 
    cat << EOF >> {{ GARAGE_AUTH_FILE }}
    [garage]
    aws_access_key_id="$KEY_ID"
    aws_secret_access_key="$KEY_SECRET"
    EOF

    rm -f $KEYFILE

    echo "wrote garage profile to {{ GARAGE_AUTH_FILE }}"


garage_create_key KEY:
    # just garage key create {{ KEY }}
    just garage_aws_keymagic {{ KEY }}
    just garage key list


garage_create_repo NAME:
    just garage_create_bucket {{ NAME }}
    just garage_create_key {{ NAME }}
    just garage bucket allow \
      --read \
      --write \
      --owner {{ NAME }} \
      --key {{ NAME }}
    just garage bucket info {{ NAME }}

start_local_docker_garage:
    #!/usr/bin/env bash
    
    # https://garagehq.deuxfleurs.fr/documentation/quick-start/

    set -ex

    DATA_DIR=$HOME/.garage
    mkdir -p $DATA_DIR

    if [ ! -f $DATA_DIR/garage.toml ]; then
        echo "\
    metadata_dir = '/var/lib/garage/meta'
    data_dir = '/var/lib/garage/data'
    db_engine = 'sqlite'

    replication_factor = 1

    rpc_bind_addr = '[::]:3901'
    rpc_public_addr = '127.0.0.1:3901'
    rpc_secret = '$(openssl rand -hex 32)'

    [s3_api]
    s3_region = 'garage'
    api_bind_addr = '[::]:3900'
    root_domain = '.s3.garage.localhost'

    [s3_web]
    bind_addr = '[::]:3902'
    root_domain = '.web.garage.localhost'
    index = 'index.html'

    [k2v_api]
    api_bind_addr = '[::]:3904'

    [admin]
    api_bind_addr = '[::]:3903'
    admin_token = '$(openssl rand -base64 32)'
    metrics_token = '$(openssl rand -base64 32)'
    " > $DATA_DIR/garage.toml
        echo "wrote garage toml file"
    fi
    
    docker start garaged || docker run \
      -d \
      --name garaged \
      --network host \
      -v $DATA_DIR/garage.toml:/etc/garage.toml \
      -v $DATA_DIR/garage/meta:/var/lib/garage/meta \
      -v $DATA_DIR/garage/data:/var/lib/garage/data \
      dxflrs/garage:v1.1.0

start_local_docker_zot ARCH:
    docker start zotd || docker run \
      -d \
      --name zotd \
      --network host \
      ghcr.io/project-zot/zot-{{ ARCH }}:latest

start_local_docker_zot_amd64:
    just start_local_docker_zot linux-amd64

start_local_docker_zot_arm64:
    just start_local_docker_zot linux-arm64

skopeo_cp:
    # https://zotregistry.dev/v2.0.1/user-guides/user-guide-datapath/#common-tasks-using-skopeo-for-oci-images
    skopeo --insecure-policy copy \
       --dest-tls-verify=false \
       --multi-arch=all \
       --format=oci \
       docker://busybox:latest \
       docker://{{ ZOT_HOST }}/busybox:latest

zot_oras_example:
    #!/usr/bin/env bash
    # see https://zotregistry.dev/

    set -euxo pipefail
    
    ARTIFACT="artifact.txt"

    # create and push the artifact
    echo 'hello world' > $ARTIFACT 
    oras push \
        --plain-http {{ ZOT_HOST }}/hello-artifact:v1 \
        --artifact-type application/vnd.acme.rocket.config \
        ./$ARTIFACT

    rm $ARTIFACT

    # now show we can pull and use the artifact
    oras pull {{ ZOT_HOST }}/hello-artifact:v1
    cat $ARTIFACT
    rm ./$ARTIFACT

regctl_ls:
    # https://zotregistry.dev/v2.0.1/user-guides/user-guide-datapath/#common-tasks-using-regclient-for-oci-images
    regctl registry set --tls=disabled {{ ZOT_HOST }}
    regctl repo ls {{ ZOT_HOST }}

echo-age-key:
    #!/usr/bin/env bash
    echo {{ PULUMI_CONFIG_PASSPHRASE }}

echo-hcloud-token:
    nu -c 'just decrypt | from yaml | get hcloud' || echo ''

encrypt-in-place:
    ansible-vault encrypt ./vault/secrets.yml

ensure-encrypted:
    #!/usr/bin/env bash
    egrep '\$ANSIBLE' vault/secrets.yml > /dev/null || (echo 'Cannot decrypt unencrypted file!' && exit 1)

decrypt-in-place: ensure-encrypted
    ansible-vault decrypt ./vault/secrets.yml

decrypt: ensure-encrypted
    ansible-vault decrypt --output - ./vault/secrets.yml 
