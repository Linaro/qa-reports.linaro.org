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

# Fast deployment (upgrade only)

To run a fast deployment, in which the only steps performed are those needed
when upgrading to new versions of squad, or of the Linaro squad plugins, you
just need to define the `upgrade_only` variable:

```
./deploy ENVIRONMENT --extra-vars upgrade_only=true site.yml
```

Doing an upgrade-only deployment is way faster then doing a full deployment,
but should only be done when you are sure that the only change that is pending
to the be applied to the system is an upgrade of squad.
