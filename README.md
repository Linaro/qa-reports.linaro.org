# deploy to production

first deploy SSL (only needed in the very first time, or if the SSL setup
changed):

```
./deploy production ssl.yml
```

Then do the rest of the deployment:

```
./deploy production
```

# deploy to development environment

start VM

```
vagrant up
```

then deploy

```
./deploy dev
```
