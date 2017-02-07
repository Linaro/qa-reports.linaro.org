# deploy to production

first deploy SSL (only needed in the very first time, or if the SSL setup
changed):

```
./go production ssl.yml
```

Then do the rest of the deployment:

```
./go production
```

# deploy to development environment

start VM

```
vagrant up
```

then deploy

```
./go dev
```
