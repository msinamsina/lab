# lab

## install docker
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/msinamsina/lab/main/Docker/install-docker-and-docker-compose.sh)"
```

Then login again:

```
su - ${USER}
```

## install 3x-ui
```bash
git clone git@github.com:msinamsina/lab.git
cd lab/x-ui
docker compose up -d
```

## Using ssh tunnel script
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/msinamsina/lab/main/ssh_tunnel/sshtun.sh)"
```

## Using x-vpn
```bahs
wget https://raw.githubusercontent.com/msinamsina/lab/refs/heads/main/x-ui/x-vpn.sh
bash ./x-vpn.sh start -l <vless link>
```
