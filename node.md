# NVM
## install nvm
see https://github.com/nvm-sh/nvm/

## list remote node
```shell
nvm ls -remote
```

## list local node
```shell
nvm ls
```

## switch node
```shell
nvm use v19.1.0
``` 

## install node by nvm
```shell
# install special version node
nvm install v19.1.0

# install lastest node
nvm install node

# install lastest lts node
nvm install --lts node 
```

# NPM
## change source
```shell
npm config set registry http://registry.npm.taobao.org/
```

## view package info
```shell
npm view vue
```