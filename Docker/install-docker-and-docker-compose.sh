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
sudo usermod -aG docker ${USER}
