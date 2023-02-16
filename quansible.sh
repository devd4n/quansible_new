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
  python3 -m pip install --upgrade pip
  python3 -m pip install virtualenv
  python3 -m venv $QUANSIBLE_VENV
  
  # update venv, install ansible in venv
  python3 -m venv $QUANSIBLE_VENV
  source $QUANSIBLE_VENV/bin/activate
  python3 -m pip install --upgrade pip
  python3 -m pip install wheel
  python3 -m pip install ansible==$ANSIBLE_VERSION
  deactivate
  return
}

function build_quansible () {
  source $QUANSIBLE_VENV/bin/activate ; \
  ansible-playbook -e path=$SCRIPT_DIR $SCRIPT_DIR/quansible/init_config.yaml --ask-become-pass $USER_ADMIN
  deactivate
  if [[ $DOCKER_MODE == true ]]
  then
     apt-get update
     apt install docker.io -y
     usermod -aG docker $USER_ADMIN
     docker build -t quansible
     docker run -it quansible
  else
     source $QUANSIBLE_VENV/bin/activate
     ansible-playbook --extra-vars @$SCRIPT_DIR/quansible/ansible_vars.yaml $SCRIPT_DIR/quansible/init_quansible.yaml --ask-become-pass
    exit
  fi
  return
}

# Run function defined by parameter of this script (setup | init)
if [[ $1 == "install" ]]
then
  prepare_environment
  su -c "quansible.sh prepare_ansible" $USER_ADMIN
  su -c "quansible.sh update-env" $USER_ADMIN
  exit
elif [[ $1 == "update-env" ]]
then
  prepare_environment
elif [[ $1 == "update-ansible" ]]
then
  prepare_ansible
elif [[ $1 == "build" ]]
then
  build_quansible
else
  echo "usage: $0 <update-env|update|update-roles|upgrade>"
  exit
fi
