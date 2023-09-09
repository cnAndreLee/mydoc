## Select a version in this web
https://go.dev/dl/

copy address and download in someplace
```
wget https://go.dev/dl/go1.17.13.linux-amd64.tar.gz
tar zxvpf go1.17.13.linux-amd64.tar.gz
mv go /usr/local/
```

in /etc/profile add 
```
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

```
source /etc/profile
```

## Network
```
go env -w GO111MODULE=on
go env -w GOPROXY=https://goproxy.cn,direct
```