# Installation of Docker and Docker Compose

# Install Docker
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Check if the keyring file exists and overwrite it
if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
    sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
fi

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce -y

# Add the current user to the docker group
sudo usermod -aG docker ${USER}

# Install Docker Compose
# Install the latest version of Docker Compose
mkdir -p ~/.docker/cli-plugins/
latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -SL https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Verify the installation
echo "|Verifying the installation... |"
echo "================================"
echo "|        Docker version        |"
docker --version
echo "================================"
echo "|    Docker Compose version    |"
docker compose version
echo "================================"