#!/bin/bash
## setup the node for jupyterlab and later for big data etc.
GITMAINFOLDER="WHOTRSURFACE20"
SPARKNAME="SparkNodes"
HOSTNAME="S2"
PYPACKAGES="numpy scipy pandas matplotlib scikit-learn jupyter ipykernel seaborn bokeh lxml netmiko jupyterlab "
CONFDIR="Conf"

# create configuration folder
if [[ ! -e $CONFDIR ]]; then
	mkdir -p $CONFDIR
fi

# get old hostname
OLDHOSTNAME=$(cat /etc/hostname)

# get current IPv4 address
IPREGEX="10.[0-9]*.[0-9]*.[0-9]*"
IPADDR=$(ifconfig -a | grep -o "inet addr:$IPREGEX")
echo $IPADDR

# ask for superuser password
sudo echo "Please enter your password:"

# update and upgrade apt packages
sudo apt-get update
sudo apt-get upgrade -y
sudo apt autoremove -y

# install VIM
sudo apt-get install vim -y

# install TMUX
sudo apt-get install tmux -y

# install Git
sudo apt-get install git -y

# install VMWare Tools
sudo apt-get install vmfs-tools -y
sudo apt-get install vmware-manager -y

# install locate
sudo apt-get install locate

# set hostname, replace with regex
sudo sed -i "s/$OLDHOSTNAME/$HOSTNAME/g" /etc/hosts
sudo sed -i "s/$OLDHOSTNAME/$HOSTNAME/g" /etc/hostname

# install OpenSSH
sudo apt-get install openssh-client -y
sudo apt-get install openssh-server -y

# install autojump
sudo apt-get install autojump -y

# install powerline
sudo apt-get install powerline -y

# get dotfiles from Github
if ! [-f Dotfiles ]; then
	git clone https://github.com/xaneon/Dotfiles/
fi

# test
ls Dotfiles/$GITMAINFOLDER

# clean up bashrc, vimrc and tmux.conf and link it
if [ -f .bashrc ]; then
	rm .bashrc
fi
if [ -f .vimrc ]; then
	rm .vimrc
fi
if [ -f .vim ]; then
	rm .vim
fi
if [ -f .tmux.conf ]; then
	rm .tmux.conf
fi

# link dotfiles to bashrc, vimrc and tmux.conf
ln -s Dotfiles/$SPARKNAME/bashrc /home/$USER/.bashrc
ln -s Dotfiles/$GITMAINFOLDER/vimrc /home/$USER/.vimrc
ln -s Dotfiles/$GITMAINFOLDER/vim /home/$USER/.vim
ln -s Dotfiles/$GITMAINFOLDER/tmux.conf /home/$USER/.tmux.conf

add_ppa() {
	grep -h "^deb.*$1" /etc/apt/sources.list.d/* > /dev/null 2>&1
	if [ $? -ne 0 ]
 	then
		echo "Adding ppa:$1"
		sudo add-apt-repository -y ppa:$1
		return 0
	fi
	echo "ppa:$1 already exists"
	return 1
}

# install python3.6 and python 3.7
sudo add_ppa ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get install python3.6 python3.6-* -y
sudo apt-get install python3.7 python3.7-* -y

# install virtualenv, virtualenvwrapper
sudo apt-get install virtualenv virtualenvwrapper -y

source /usr/share/virtualenvwrapper/virtualenvwrapper.sh

# exec bash

# create virutalenvs
P36DIR=$(which python3.6)
P37DIR=$(which python3.7)
mkvirtualenv D3.6 "--python=$P36DIR"
pip install $PYPACKAGES
pip freeze > $CONFDIR/requirements_d36.txt
deactivate
mkvirtualenv D3.7 "--python=$P37DIR" 
pip install $PYPACKAGES
pip freeze > $CONFDIR/requirements_d37.txt
deactivate

# create ssh key
ssh-keygen -b 4096 -t rsa -N "" -f ~/.ssh/id_rsa

# set up the sshd
AKEYCMD="AuthorizedKeysFile	%h/.ssh/authorized_keys"
sudo sed -i "s/RSAAuthentication no/RSAAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/PubkeyAuthentication no/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
# sudo sed -i "s/# $AKEYCMD/$AKEYCMD/g" /etc/ssh/sshd_config
# TODO: not working yet

sudo service ssh restart && sudo service sshd restart

if [ -f ~/.ssh/id_rsa.pub ]; then
	mv ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
fi

chmod 600 ~/.ssh/authorized_keys

# reboot
# sudo reboot

