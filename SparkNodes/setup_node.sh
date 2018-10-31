#!/bin/bash
## setup the node for jupyterlab and later for big data etc.
GITMAINFOLDER="WHOTRSURFACE20"
SPARKNAME="SparkNodes"
HOSTNAME="S2"
JUPYTERPORT=9999
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

# install htop
sudo apt-get install htop -y

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
if [ -f replace ]; then
	rm replace
fi
if [ -f .tmux.conf ]; then
	rm .tmux.conf
fi

# link dotfiles to bashrc, vimrc and tmux.conf
ln -s Dotfiles/$SPARKNAME/bashrc /home/$USER/.bashrc
ln -s Dotfiles/$SPARKNAME/replace /home/$USER/replace
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
# this does not seem to work without problems, at the moment it is 
# necessary to add the repository once explicitly 
sudo add_ppa deadsnakes/ppa
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
AKEYCMD="#AuthorizedKeysFile	%h/.ssh/authorized_keys"
AKEYCMD2="AuthorizedKeysFile	%h/.ssh/authorized_keys"
sudo sed -i "s/RSAAuthentication no/RSAAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/PubkeyAuthentication no/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
# sudo sed -i "s/# $AKEYCMD/$AKEYCMD/g" /etc/ssh/sshd_config
sudo ./replace "/etc/ssh/sshd_config" "$AKEYCMD" "$AKEYCMD2"
# TODO: not working yet

sudo service ssh restart && sudo service sshd restart

if [ -f ~/.ssh/id_rsa.pub ]; then
	mv ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
fi

chmod 600 ~/.ssh/authorized_keys

# generate the Jupyter config
jupyter notebook --generate-config

# generate Jupyter password
jupyter notebook password

# generate the authentication key
# openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout ~/.jupyter/mykey.key -out ~/.jupyter/mycert.pem
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ~/.jupyter/mykey.key -out ~/.jupyter/mycert.pem

SHAKEY=$(python3.6 -c "from notebook.auth import passwd; print(passwd()[5:])")
# echo $SHAKEY

# change the contents of the jupyter_notebook_config.py
# sed -i -e 's/'"$NOTEBOOKCERTFILESTR"'/'"$NOTEBOOKCERTFILESTRNEW"'/g' ~/.jupyter/jupyter_notebook_config.py
C1="#c.NotebookApp.certfile = ''" 
C2="c.NotebookApp.certfile = '$HOME/.jupyter/mycert.pem'"
C3="#c.NotebookApp.ip = 'localhost'"
C4="c.NotebookApp.ip = '0.0.0.0'"
C5="#c.NotebookApp.keyfile = ''" 
C6="c.NotebookApp.keyfile = '$HOME/.jupyter/mykey.key'" 
C7="#c.NotebookApp.open_browser = True"
C8="c.NotebookApp.open_browser = False"
C9="#c.NotebookApp.password = ''"
C10="c.NotebookApp.password = '$SHAKEY'"
C11="#c.NotebookApp.port = 8888"
C12="c.NotebookApp.port = $JUPYTERPORT"
C13="#c.NotebookApp.notebook_dir = ''"
C14="c.NotebookApp.notebook_dir = '$HOME/Notebooks'"
C15="#c.Session.username = '$USER'"
C16="c.Session.username = '$USER'"
C17="#c.NotebookApp.base_url = '/'"
C18="c.NotebookApp.base_url = '/$USER'"
FN="$HOME/.jupyter/jupyter_notebook_config.py"
# sed -i 's|$C1|$C2"|g' ~/.jupyter/jupyter_notebook_config.py
./replace $FN "$C1" "$C2"
./replace $FN "$C3" "$C4"
./replace $FN "$C5" "$C6"
./replace $FN "$C7" "$C8"
./replace $FN "$C9" "$C10"
./replace $FN "$C11" "$C12"
./replace $FN "$C13" "$C14"
./replace $FN "$C15" "$C16"
./replace $FN "$C17" "$C18"

# clone latest excercises
git clone https://gitlab.com/xaneon/kiml.git
cp -rf kiml/Uebungsaufgaben/Notebooks .
rm -rf kiml

# start jupyter notebook server (optional)
# jupyter notebook --certfile=~/.jupyter/mycert.pem --keyfile ~/.jupyter/mykey.key
# jupyter-lab --certfile=~/.jupyter/mycert.pem --keyfile ~/.jupyter/mykey.key

#NOTE: So far it is working for one user, now you should create student1-6 on each node
J1USER="student1"
if getent passwd $J1USER > /dev/null 2>&1; then
	sudo userdel --remove-home $J1USER
	sudo useradd $J1USER --create-home --password "$(openssl passwd -1 "$J1USER")" --shell /bin/bash --uid 5012 --user-group
	sudo su - $J1USER
else
	sudo useradd $J1USER --create-home --password "$(openssl passwd -1 "$J1USER")" --shell /bin/bash --uid 5012 --user-group
	sudo su - $J1USER

fi
# reboot
# sudo reboot

