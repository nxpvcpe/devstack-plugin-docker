#!/bin/bash
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set -o xtrace

DOCKER_UNIX_SOCKET=/var/run/docker.sock

DOCKER_CHECK=$(which docker|wc -l)

if [[ "$1" == "stack" && "$2" == "pre-install" && "$DOCKER_CHECK" -eq "0"  ]]; then
	if [[ "$DOCKER_CHECK" -eq "0" ]]; then
	sudo apt-get update
	sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates curl software-properties-common
	curl -fksSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update
	sudo apt-get install -y docker-ce
	fi

elif [[ "$1" == "stack" && "$2" == "install" ]]; then
	
	if [[ ! -d /opt/stack/nova-docker/ ]]; then
	git clone https://github.com/openstack/nova-docker.git -b stable/mitaka /opt/stack/nova-docker/
	OLD_PTH=$(pwd)
	cd /opt/stack/nova-docker/
	sudo pip install docker-py
	sudo python setup.py install
	cd $OLD_PTH
	fi

	restart_service docker

    if [ -f "/etc/default/docker" ]; then
        sudo cat /etc/default/docker
        sudo sed -i 's/^.*DOCKER_OPTS=.*$/DOCKER_OPTS=\"--debug --storage-opt dm.override_udev_sync_check=true\"/' /etc/default/docker
        sudo cat /etc/default/docker
    fi

    if [ -f "/etc/sysconfig/docker" ]; then
        sudo cat /etc/sysconfig/docker
        sudo sed -i 's/^.*OPTIONS=.*$/OPTIONS=--debug --selinux-enabled/' /etc/sysconfig/docker
        sudo cat /etc/sysconfig/docker
    fi

    if [ -f "/usr/lib/systemd/system/docker.service" ]; then
        sudo cat /usr/lib/systemd/system/docker.service
        sudo sed -i 's/docker daemon/docker daemon --debug/' /usr/lib/systemd/system/docker.service
        sudo cat /usr/lib/systemd/system/docker.service
        sudo systemctl daemon-reload
    fi

	echo "Waiting for docker daemon to start..."
    DOCKER_GROUP=$(groups | cut -d' ' -f1)
    CONFIGURE_CMD="while ! /bin/echo -e 'GET /version HTTP/1.0\n\n' | socat - unix-connect:$DOCKER_UNIX_SOCKET 2>/dev/null | grep -q '200 OK'; do
      # Set the right group on docker unix socket before retrying
      sudo chgrp $DOCKER_GROUP $DOCKER_UNIX_SOCKET	
      sudo chmod g+rw $DOCKER_UNIX_SOCKET
      sleep 1
    done"

elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        if [[ ! -e /etc/nova/rootwrap.d/docker.filters ]]; then
        sudo cp /opt/stack/nova-docker/etc/nova/rootwrap.d/docker.filters /etc/nova/rootwrap.d
        fi

elif [[ "$1" == "unstack" ]]; then
    echo_summary "Running unstack"
    stop_service docker


fi

# Restore xtrace
$XTRACE
