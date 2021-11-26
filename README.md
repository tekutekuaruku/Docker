## Description


## Usage

- build
```
docker build . -t ft_server:latest
```

- run
```
docker run --rm -it -p8080:80 -p443:443 ft_server:latest
```
- run-off
```
docker run --rm -it --env NGINX_AUTO_INDEX="off" -p8080:80 -p443:443 ft_server:latest
```

- clean
```
docker rmi ft_server
```
