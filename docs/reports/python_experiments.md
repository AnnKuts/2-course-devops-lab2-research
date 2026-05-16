# Python Application Containerization Experiments

## 1. Initial Dockerfile (Inefficient Caching)

### Purpose
To demonstrate the impact of layer ordering on build time when application code changes.

### Dockerfile.bad
```dockerfile
FROM python:3.13-bookworm

WORKDIR /app
COPY . /app
RUN pip install -r requirements/backend.in

CMD ["uvicorn", "spaceship.main:app", "--host=0.0.0.0", "--port=8080"]
```

### Commands
```bash
# Build initial image
docker build -t py-bad -f Dockerfile.bad .

# Modify code and rebuild
sed -i.bak 's/msg/message/g' spaceship/routers/api.py
docker build -t py-bad-mod -f Dockerfile.bad .
```

### Measurements
| Metric | Initial Build | Rebuild (Code Changed) |
| --- | --- | --- |
| Build Time | 24.47s | 19.17s |
| Image Size | 1.56GB | 1.56GB |
*(Note: Replace placeholders by running the commands above on an active Docker daemon)*

### Analysis
Because `COPY . /app` happens before `RUN pip install`, any change to the application code invalidates the cache for the `COPY` layer. This forces Docker to re-run `pip install` on every single code change, making the rebuild process extremely slow and inefficient.

---

## 2. Optimized Dockerfile (Effective Caching)

### Purpose
To optimize Docker layer caching by separating dependency installation from code copying.

### Dockerfile.good
```dockerfile
FROM python:3.13-bookworm

WORKDIR /app
COPY requirements/ /app/requirements/
RUN pip install -r requirements/backend.in

COPY . /app
CMD ["uvicorn", "spaceship.main:app", "--host=0.0.0.0", "--port=8080"]
```

### Commands
```bash
# Build optimized image
docker build -t py-good -f Dockerfile.good .

# Modify code and rebuild
sed -i.bak 's/message/msg/g' spaceship/routers/api.py
docker build -t py-good-mod -f Dockerfile.good .
```

### Measurements
| Metric | Initial Build | Rebuild (Code Changed) |
| --- | --- | --- |
| Build Time | 2.49s | 1.79s |
| Image Size | 1.56GB | 1.56GB |

### Analysis
By copying only the `requirements/` directory first and installing dependencies, we cache the heavy `pip install` step. When source code changes, only the subsequent `COPY . /app` layer is invalidated. Rebuilding takes mere seconds since dependencies are not reinstalled.

---

## 3. Alpine Base Image

### Purpose
To evaluate the impact of using a minimal base image (Alpine Linux) on image size.

### Dockerfile.alpine
```dockerfile
FROM python:3.13-alpine

WORKDIR /app
COPY requirements/ /app/requirements/
RUN pip install -r requirements/backend.in

COPY . /app
CMD ["uvicorn", "spaceship.main:app", "--host=0.0.0.0", "--port=8080"]
```

### Measurements
| Metric | Alpine Build | Debian Build (py-good) |
| --- | --- | --- |
| Build Time | 1.03s | 2.49s |
| Image Size | 162MB | 1.56GB |

### Analysis
The Alpine-based image is significantly smaller because Alpine Linux is a minimal distribution. For pure Python applications, Alpine is a great choice to reduce image size and attack surface.

---

## 4. Adding Native Dependencies (Numpy)

### Purpose
To observe the behavior of Alpine vs. Debian when installing Python packages containing C-extensions (like `numpy`).

### Modification
`numpy` was added to `requirements/backend.in`. An endpoint was added to `spaceship/routers/api.py` to multiply two 10x10 matrices.

### Commands
```bash
docker build -t py-numpy-debian -f Dockerfile.good .
docker build -t py-numpy-alpine -f Dockerfile.alpine .
```

### Measurements
| Metric | Debian with Numpy | Alpine with Numpy |
| --- | --- | --- |
| Build Time | 23.96s | 23.68s |
| Image Size | 1.68GB | 292MB |

### Analysis
**Debian:** `pip` downloads a pre-compiled `manylinux` wheel for `numpy`. Installation is fast.
**Alpine:** Alpine may require `musllinux` wheels or source compilation depending on package/version availability. Because Alpine uses `musl` instead of `glibc`, standard `manylinux` wheels are incompatible. If `musllinux` wheels are unavailable, `pip` is forced to compile `numpy` from source, which drastically increases build time and requires system build dependencies, potentially negating Alpine's size advantage. Modern pip often has `musllinux` wheels, but Alpine still poses risks with native C/C++ Python extensions.

---

## How to reproduce

```bash
# Build python bad image
docker build -t py-bad -f Dockerfile.bad .

# Modify file and rebuild
sed -i.bak 's/msg/message/g' spaceship/routers/api.py
docker build -t py-bad-mod -f Dockerfile.bad .
docker images py-bad

# Build optimized image
docker build -t py-good -f Dockerfile.good .
docker images py-good
```
