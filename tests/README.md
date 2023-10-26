# Test

If the env variables are not defined:
```sh
make aws-auth AWS_ACCESS_KEY=*** AWS_SECRET_KEY=*** AWS_REGION_NAME=***
make prepare AWS_ACCOUNT_ID=*** AWS_REGION_NAME=***
```

otherwise:
```sh
make aws-auth
make prepare
```

Then:
```sh
go test -p 1
```

If you want to test again without the cache result:
```sh
make test-clear
```