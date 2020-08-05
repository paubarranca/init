#!/bin/bash -e

check_if_host_exists() {

	if [ ! -f $SSH_KNOWN_HOSTS_FILE ]; then
		touch $SSH_KNOWN_HOSTS_FILE
		ssh-keyscan github.com >> $SSH_KNOWN_HOSTS_FILE 2>/dev/null 
		echo -e "\nCreated $SSH_KNOWN_HOSTS_FILE and added github host as known"
	elif [ ! -n "$(grep "^github.com " $SSH_KNOWN_HOSTS_FILE)" ]; then 
		ssh-keyscan github.com >> $SSH_KNOWN_HOSTS_FILE 2>/dev/null
		echo -e "\nAdded github host as known"
	else 
		echo -e "\nGithub host already exists in $SSH_KNOWN_HOSTS_FILE... Skipping..."
	fi
}

# Constants
GIT_KEY=~/.ssh/git-$1-key
SSH_CONFIG_FILE=~/.ssh/config
SSH_KNOWN_HOSTS_FILE=~/.ssh/known_hosts

# Check that the right number of parameters have been passed
if [[ "$#" -ne 3 ]]; then
	echo -e "\nSCRIPT USAGE: ./git-init.sh githubuser githubmail repositoryname \nEXAMPLE: ./git-init.sh johnwilliams john.williams@gmail.com johnwilliams/docker-test\n"
	exit 1
else 
	read -p "Where do you want to pull the repository $3? (use the absolute path, for example ~/repositoryname) : "  REPO_PATH
fi

if [[ ! -d $REPO_PATH ]]; then
	mkdir -p $REPO_PATH
fi

if [ ! $(which git) ]; then
	apt install git
fi

git config --global user.name $1
git config --global user.email $2

# Create new key pair if it doesn't exist
if [[ -f $GIT_KEY ]]; then
	echo -e "\nKey pair already exist... Skipping..."
else
	ssh-keygen -t rsa -N "" -f $GIT_KEY
	echo -e "\nPublic key to add on GitHub ssh keys:"
	cat $GIT_KEY.pub
	echo -e "\n\n"
	read -n 1 -s -r -p "Press enter when your key is added on GitHub ....."
fi

# Use the created key for github hostname
if grep --quiet $GIT_KEY $SSH_CONFIG_FILE; then
	echo -e "\nKey already exists in $SSH_CONFIG_FILE... Skipping..." 
	check_if_host_exists
else 
	cat <<EOF >> $SSH_CONFIG_FILE
Host github.com
    HostName github.com
    IdentityFile $GIT_KEY
EOF

	check_if_host_exists
fi

# Set origin to push automatically via vscode
cd $REPO_PATH
git init

git remote add origin git@github.com:$3.git
git pull git@github.com:$3.git

if [[ $? -eq 0 ]]; then
	echo -e "\nRepository pulled succesfully, available at $REPO_PATH"
	exit 0
else
	echo -e "\nERROR: Respository not pulled succesfully, Check if you have correct permissions on the pulled directory, if the public ssh key is correctly associated in GitHub or if the repository name is spelled correctly"
	exit 2
fi
