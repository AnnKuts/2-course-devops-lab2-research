# DNS Resolution: Musl (Alpine) vs Glibc (Ubuntu/Debian)

## Purpose
To investigate how different C standard libraries (`musl` in Alpine vs `glibc` in Ubuntu) handle DNS resolution, specifically regarding DNS search domains.

## Commands

1. **Create network and start DNS server (dnsmasq):**
```bash
docker network create dns-lab
docker run -d --name dns-server --network dns-lab alpine sh -c "apk add --no-cache dnsmasq && echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && dnsmasq -k --log-queries --log-facility=-"
```

2. **Test resolution from Ubuntu (glibc):**
```bash
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal
```

3. **Test resolution from Alpine (musl):**
```bash
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  alpine:latest getent hosts myservice.internal
```

## Expected Results
- **Ubuntu:** `10.0.0.50 myservice.internal.corp` (Success)
- **Alpine:** Returns empty or `getent hosts: No such file or directory` / NXDOMAIN (Failure)

## Analysis

### Glibc (Ubuntu)
The `glibc` resolver correctly respects the `--dns-search="corp"` parameter. When resolving `myservice.internal`, it fails the initial exact lookup, appends the `.corp` search domain, queries `myservice.internal.corp`, and successfully gets the IP `10.0.0.50`.

### Musl (Alpine)
The `musl` libc resolver behaves strictly according to different POSIX interpretations. If a hostname contains a dot (like `myservice.internal`), `musl` considers it a Fully Qualified Domain Name (FQDN) or relies on `ndots=1` logic without falling back to search domains if the initial query fails. Therefore, `musl` queries `myservice.internal` exactly, gets an NXDOMAIN from the DNS server, and **never appends** the `corp` search domain.

### Conclusions and Risks
This difference in behavior can lead to unexpected service discovery issues in microservice environments like Kubernetes, which heavily rely on DNS search domains for service discovery (e.g., resolving `service.namespace` instead of `service.namespace.svc.cluster.local`). 
Using Alpine for applications that need complex DNS resolution can result in "Host not found" errors that are notoriously difficult to debug because the exact same configuration works perfectly on Debian/Ubuntu based images.

## How to reproduce

```bash
# Create network and start dnsmasq
docker network create dns-lab
docker run -d --name dns-server --network dns-lab alpine sh -c "apk add --no-cache dnsmasq && echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && dnsmasq -k --log-queries --log-facility=-"

# Test Ubuntu
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal

# Test Alpine
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  alpine:latest getent hosts myservice.internal

# Cleanup
docker rm -f dns-server
docker network rm dns-lab
```
