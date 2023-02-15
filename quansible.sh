#!/bin/bash

SCRIPT_DIR=""
USER_ADMIN=""
ROOT_DIR=""
QUANSIBLE_VENV=""
DOCKER_MODE=""
ANSIBLE_VERSION=""

function prepare_environment () {
  apt update
  # Install system requirements and apps for virtualenv
  apt install curl sudo python3-pip python3-venv -y
  # https://www.codegrepper.com/code-examples/shell/python+headers+are+missing+in+%2Fusr%2Finclude%2Fpython3.6m+%26quot%3Byum%26quot%3B
  # https://stackoverflow.com/questions/31508612/pip-install-unable-to-find-ffi-h-even-though-it-recognizes-libffi
  apt install python-dev python3-dev libffi-dev -y
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=998232
  #curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  # ansible needs a UTF-8 locale
  
  snap install yq
  SCRIPT_DIR=$(pwd)
  USER_ADMIN="$(yq e '.quansible_user_admin' quansible/config.yaml)"
  ROOT_DIR="$(yq e '.quansible_root_dir' quansible/config.yaml)"
  DOCKER_MODE="$(yq e '.docker-mode' quansible/config.yaml)"
  ANSIBLE_VERSION="$(yq e '.quansible_ansible_version' quansible/config.yaml)"
  QUANSIBLE_VENV=$SCRIPT_DIR/venv
  useradd -m $USER_ADMIN --shell /bin/bash
  echo "$USER_ADMIN ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USER_ADMIN

  # give full ownership to the ansible user
  #chown -R $USER_ADMIN:$USER_ADMIN $SCRIPT_DIR
  locale-gen en_GB.UTF-8
  #locale-gen en_GB
  update-locale LANG=en_GB.UTF-8
  return
}

# update quansible environment
function prepare_ansible () {
  # update user pip and initiate venv
  su -c "python3 -m pip install --upgrade pip ; \
    pip install virtualenv ; \
    venv $QUANSIBLE_VENV" $USER_ADMIN
  
  # update venv, install ansible in venv
  su -c "venv $QUANSIBLE_VENV && \
    source $QUANSIBLE_VENV/bin/activate ;  \
    python3 -m pip install --upgrade pip ; \
    python3 -m pip install wheel ; \
    python3 -m pip install ansible==$ANSIBLE_VERSION" $USER_ADMIN 
  return
}

function build_quansible () {
  su $USER_ADMIN
  source $QUANSIBLE_VENV/bin/activate
  ansible-playbook --extra-vars "nodes=localhost path=$SCRIPT_DIR" "$SCRIPT_DIR/quansible/init_config.yaml" --ask-become-pass
  #deactivate
  if [[ $DOCKER_MODE == true ]]
  then
     sudo apt-get update
     sudo apt install docker.io -y
     sudo usermod -aG docker $USER_ADMIN
     docker build -t quansible
     docker run -it quansible
     exit
  else
    ansible-playbook --extra-vars  @"$SCRIPT_DIR/quansible/ansible_vars.yaml" $SCRIPT_DIR/quansible/init_config.yaml --ask-become-pass
    exit
  fi
  return
}

# Run function defined by parameter of this script (setup | init)
if [[ $1 == "setup-env" ]]
then
  prepare_environment
  prepare_ansible
  #build_quansible
  exit
elif [[ $1 == "update" ]]
then
  echo "currently not available"
else
  echo "usage: $0 <setup-env|update|update-roles|upgrade>"
  exit
fi
