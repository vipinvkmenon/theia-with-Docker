# Theia-with-Dind

This repo builds theia with the following tooling:

- docker (dind)
- kubectl
- kyma cli
- istioctl
- helm

## To Build

Clone and build the image as
```
docker build . -t <tag:version>
```
## To run:

```
docker run --privileged -p 3000:3000 <tag:version>
```
Give it about a minute to load...You should see the last log message as
```
.... Start of 65 plugins took ...
```

# Using the environment

- Open `localhost:3000` in your browser, theia will load up
- To start the docker daemon click `Terminal->New Terminal`. A terminal window will open in the bottom. In the terminal run `start-dockerd`. You will see the logs for dockerd loading up. This will take a few seconds with the final log as 
```
INFO[xxx] API listen on /run/user/1001/docker.sock     
INFO[xxx] API listen on [::]:2376  
```
- In a new terminal, run `init-docker-env`. The prompt will change. 
- Try running the command `docker info` to ensure everything is running
- Try running `kubectl`, `kyma` , `istioctl`, `helm`  to see if the commands work.



