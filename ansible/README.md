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

# deploy to a non-Linaro environment

Create a file called `hosts.local` with the following contents (replace
`squad.mycompany.com` with the hostname squad will be deployed to):

```
[production]
squad.mycompany.com

[staging]
staging-squad.mycompany.com
```

Then do the deployment normally:

```
./deploy production # or staging etc
```
