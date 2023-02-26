find . "(" -path ./vue/node_modules -prune -or -name "*.go" -or -name "*.vue" -or -name "*.js" -or -name "*.ts" ")" -print | xargs wc -l^C
