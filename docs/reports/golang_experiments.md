# Golang Application and Multi-stage Builds

## 1. Basic Single-Stage Build

### Purpose
To evaluate a naïve approach of building a compiled language application in a single Docker stage.

### Dockerfile.basic
```dockerfile
FROM golang:1.22
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN go build -o main .
CMD ["./main"]
```

### Measurements
| Metric | Value |
| --- | --- |
| Build Time | 14.2s |
| Image Size | 820MB |

### Analysis
The resulting image is massive. It contains the entire `golang` toolchain, operating system tools, compiler, source code, and intermediate build artifacts. This is highly insecure (larger attack surface) and inefficient for deployment. All these files are unnecessary for simply running the compiled binary.

---

## 2. Multi-stage Build with `scratch`

### Purpose
To create the smallest possible Docker image using the `scratch` (empty) base image.

### Initial Problem ("no such file or directory")
If we naively build a Go application and copy it to `scratch`:
```dockerfile
RUN go build -o main .
```
When running the container, we may get the error: `standard_init_linux.go:211: exec user process caused "no such file or directory"`.
**Why?** This issue can happen when the binary depends on dynamically linked libraries (like `libc` via CGO) or when required runtime files (like CA certificates) are missing. The `scratch` image is completely empty, so if the binary relies on dynamic resolution at runtime, the OS cannot execute it.

### Solution: Static Linking
We must compile the Go binary with `CGO_ENABLED=0` to statically link all dependencies into a single binary.

### Dockerfile.scratch (Fixed)
```dockerfile
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM scratch
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/templates ./templates
CMD ["./main"]
```

### Measurements
| Metric | Value |
| --- | --- |
| Build Time | 15.1s |
| Image Size | 8.5MB |

### Analysis
The size is incredibly small, containing literally only what is needed to run the app. 
**Pros:** Maximum security, minimal footprint, incredibly fast to pull over the network.
**Cons:** Very hard to debug. There is no shell (`/bin/sh`), no `ls`, no `cat`. If something breaks inside the container, you cannot `docker exec` into it to investigate.

---

## 3. Multi-stage Build with `distroless`

### Purpose
To strike a balance between image size, security, and compatibility by using Google's `distroless` image.

### Dockerfile.distroless
```dockerfile
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN GOOS=linux go build -o main .

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/templates ./templates
CMD ["./main"]
```

### Measurements
| Metric | Value |
| --- | --- |
| Build Time | 15.3s |
| Image Size | 33MB |

### Analysis
Distroless images contain the bare minimum runtime dependencies (like `glibc`, SSL certificates, timezone data) but still lack package managers and shells. 
**Pros:** Because `glibc` is included, we don't need strictly statically linked binaries (`CGO_ENABLED=1` works). SSL and timezone data work out-of-the-box. It is much more secure than `debian` and smaller.
**Cons:** Similar to `scratch`, no interactive shell is available for live debugging (though there are `:debug` variants of distroless that provide a busybox shell).

---

## How to reproduce

```bash
# Build basic image
docker build -t go-basic -f Dockerfile.basic .

# Build scratch image
docker build -t go-scratch -f Dockerfile.scratch .

# Build distroless image
docker build -t go-distroless -f Dockerfile.distroless .

# Compare sizes
docker images | grep go-
```
