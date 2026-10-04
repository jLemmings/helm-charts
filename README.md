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

## WineVault OpenAI key with External Secrets

[WineVault v0.0.3](https://github.com/jLemmings/WineVault/releases/tag/v0.0.3)
reads `OPENAI_API_KEY` for label-photo recognition. Configure the chart to read it
from a Kubernetes Secret populated by External Secrets Operator:

```yaml
openai:
  existingSecret: winevault-openai
  secretKey: OPENAI_API_KEY
```

With External Secrets Operator installed and a configured `ClusterSecretStore`,
apply this separate manifest in the WineVault release namespace. Replace
`my-secret-store` and `winevault/openai-api-key` with your store name and remote
secret identifier. This example expects the remote secret's entire value to be
the API key; add `remoteRef.property` if it is stored in a JSON field.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: winevault-openai
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: my-secret-store
    kind: ClusterSecretStore
  target:
    name: winevault-openai
    creationPolicy: Owner
  data:
    - secretKey: OPENAI_API_KEY
      remoteRef:
        key: winevault/openai-api-key
```

See the [ExternalSecret documentation](https://external-secrets.io/latest/api/externalsecret/)
for provider mappings. The chart references the generated Secret without creating
or owning it. Keep the API key in your external secret store, not Helm values.
If you use a namespaced `SecretStore`, change the kind and place it in the same
namespace. Wait for the ExternalSecret to become Ready before starting WineVault;
a configured Secret or key that is missing prevents the container from starting.

Leave `openai.existingSecret` empty to omit the key; manual entry and barcode
lookup still work. After key rotation has synced, restart the WineVault Deployment
to reload the environment (for the default deployment name:
`kubectl rollout restart deployment/winevault -n <namespace>`).

## WineVault GrapeMinds key with External Secrets

WineVault reads `GRAPEMINDS_API_KEY` at startup for wine information enrichment.
The log status `not_configured` means that key was missing or blank in the running
backend. Configure these Helm values:

```yaml
grapeminds:
  existingSecret: winevault-grapeminds
  secretKey: GRAPEMINDS_API_KEY
```

With External Secrets Operator and your store already configured, apply this
manifest in the WineVault namespace. Replace the store name and remote secret
identifier with your own:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: winevault-grapeminds
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: my-secret-store
    kind: ClusterSecretStore
  target:
    name: winevault-grapeminds
    creationPolicy: Owner
  data:
    - secretKey: GRAPEMINDS_API_KEY
      remoteRef:
        key: winevault/grapeminds-api-key
```

The remote value should be the API key; add `remoteRef.property` if the key is
stored in a JSON field. For a namespaced store, use `kind: SecretStore` in the
same namespace. The chart only references the generated Secret. You can also
use a shared Secret with OpenAI by setting both `existingSecret` values to its
name and selecting the appropriate keys.

Wait for the ExternalSecret to become Ready, then upgrade the release with these
values. A configured Secret or key that is missing prevents container startup.
Leave `grapeminds.existingSecret` empty to omit the environment variable.
After a key change has synced, restart WineVault to reload it:
`kubectl rollout restart deployment/winevault -n <namespace>` (default deployment
name). Retry the affected wine's information fetch in the UI after restart.

## WineVault health probes

The probes match the [v0.0.3 authentication routes](https://github.com/jLemmings/WineVault/blob/v0.0.3/backend/auth.go)
and run through the Nuxt frontend and its Go API proxy:

- Startup and readiness use `GET /api/auth/status` on the named `http` port.
  This public endpoint queries PostgreSQL and returns 200 even before owner setup.
  Database failures return 503. The six-second probe timeout allows the backend's
  five-second database timeout to finish.
- Liveness uses the image's curl to request `/api/health` without a session and
  requires the expected 401. In this release, authentication rejects that request
  before any database query. This detects an unavailable Go backend even when
  Nuxt remains running, without restarting healthy processes during a database
  outage. Connection errors, timeouts, and unexpected HTTP statuses fail the probe.
- The startup probe allows approximately three minutes for initialization before
  restarting the container; readiness and liveness start after startup succeeds.

Configure timings or replace probes under `app.startupProbe`,
`app.readinessProbe`, and `app.livenessProbe`; set a probe to `null` to disable it.
When replacing a handler type, set the old handler (`httpGet` or `exec`) to `null`
so Helm does not merge both into one probe.
All probes follow `service.port` (the frontend's `PORT`). Keep `app.env.httpAddr`
at `:8080`: the upstream Nuxt proxy targets `127.0.0.1:8080`.
Recheck the liveness status expectation when upgrading WineVault's authentication
behavior. The default `latest` image tag is mutable; pin a tested release image
for reproducible deployments.

Run `./tests/winevault-probes.ps1` from PowerShell with Helm and Docker available
to validate rendering and smoke-test the `0.0.3` image. The test uses temporary
containers with no published ports and checks initial readiness, a database
outage, and a Go backend failure while Nuxt stays up, then removes its resources.
