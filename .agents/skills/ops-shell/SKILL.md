---
name: ops-shell
description: Connect to GitHub's ops-shell via SSH for infrastructure operations. Provides vault login, kubectl, vault-secret, gh-instance, kubectx/kubens access.
---

# Ops Shell Skill

Connects to GitHub's internal ops-shell and authenticates with Vault for infrastructure operations.

## Login Process

1. **SSH to ops-shell:**
   ```bash
   ssh shell
   ```
   Uses SSH config alias `shell` → `shell.service.ac4-iad.github.net` via `bastion.githubapp.com` proxy jump.
   User: `fredsh2k`. Uses ControlMaster for connection reuse.

2. **Switch to zsh:**
   ```bash
   zsh
   ```

3. **Vault login** (interactive — requires user participation):
   ```bash
   . ./vault-login
   ```
   - Prompts for **github.com password** (LDAP) — ask the user to provide the password, then type it into the prompt via `write_bash`
   - Generates a **FIDO challenge URL** — share the URL with the user and wait for them to approve it
   - On success: sets `VAULT_TOKEN` env var and prints "Successfully authenticated"
   - The password prompt does NOT echo input. Empty password causes "passwordless binds denied" error.
   - If SSH itself prompts for a password, ask the user to provide it as well.

### ⚠️ PRODUCTION ENVIRONMENT — Safety Rules
- **This is a production host.** Never execute destructive or mutating commands without explicit user approval.
- **Always ask before**: `kubectl delete`, `kubectl edit`, `kubectl apply`, `kubectl patch`, `kubectl scale`, `vault-secret --key <key> --value/--prompt` (write/update), `gh-instance create`, `gh-instance destroy`, or any command that modifies state.
- **Safe to run without asking**: read-only commands like `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectx`, `kubens`, `vault-secret` (read-only, without `--value`/`--prompt`/`--value-from-file`), `gh-instance show`, `gh-instance check`.
- If unsure whether a command is read-only, ask the user first.

### Important Notes
- The shell session is interactive (async mode). Use `write_bash` to send commands and `read_bash` to get output.
- Zsh on the ops-shell has aggressive line-editing that garbles heredocs and long commands. Keep commands short and simple. To transfer scripts, use `scp` from the local machine to `shell:/tmp/` rather than inline heredocs.
- `--context` is the correct kubectl flag for cluster selection (NOT `--cluster`).

## Available Tools

### kubectl
Query Kubernetes resources across clusters.
```bash
kubectl get deploy -n <namespace> --context <cluster>
kubectl get pods -n <namespace> --context <cluster>
kubectl logs <pod> -n <namespace> --context <cluster>
kubectl get secrets -n <namespace> --context <cluster>
```

### kubectx
List or switch Kubernetes cluster contexts.
```bash
kubectx                        # list all clusters
kubectx | grep general         # filter clusters
```
Cluster naming: `<type>-<num>-<site>` e.g. `general-1-ash1-iad`, `dotcom-2-gc-cus-02`, `actions-1-azure-eastus`.

### kubens
List namespaces in a cluster.
```bash
kubens --context <cluster>
```
Namespace convention: `<app>-<environment>` e.g. `chatterbox-staging`, `heaven-production`.

### vault-secret
Read/write secrets stored in Vault. Requires `VAULT_TOKEN` to be set.
```bash
# Read all secrets for an app/env
vault-secret --application <app> --environment <env>

# Read a specific secret key
vault-secret --application <app> --environment <env> --key <key>

# Write a secret (interactive prompt for value)
vault-secret --application <app> --environment <env> --key <key> --prompt
```

### gh-instance
CLI for the Provisioning Service. Manages app instances. Uses `key=value` pairs for filtering.
```bash
gh-instance list app=<app> environment=<env>   # list instances for an app/env
gh-instance show <hostname>                     # show instance details
gh-instance check <hostname>                    # check instance status
```
Note: `list` uses positional `key=value` filters. `show`/`check` take a single hostname identifier (from `list` output).

## Quick Start Example

```bash
# Connect and authenticate
ssh shell
zsh
. ./vault-login   # enter password, approve FIDO link

# Explore k8s
kubectx | grep general
kubectl get deploy -n chatterbox-staging --context general-1-ash1-iad

# Check secrets
vault-secret --application chatterbox --environment staging
```
