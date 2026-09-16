# helm-charts


## Add this Helm repository
```console
helm repo add jlemmings https://jlemmings.github.io/helm-charts
helm repo list
```

## Update and show charts
```console
helm repo update
helm search repo jlemmings
```

## WineVault with an existing database

Like the DiveVault chart, WineVault can create an application database Secret from
`database.url`, or reference an existing Secret with `database.existingSecret`.
Set `postgres.enabled: false` when using an external URL. Selecting an existing
Secret automatically omits the bundled PostgreSQL resources.

CloudNativePG creates an application Secret named `<cluster>-app` whose `uri` key
can be consumed directly:

```yaml
database:
  existingSecret: winevault-db-app
  secretKey: uri
```

The Secret and the WineVault release must be in the same namespace.
