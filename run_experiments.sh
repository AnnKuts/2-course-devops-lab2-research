#!/bin/bash
set -e

echo "=== PYTHON EXPERIMENTS ==="
cd python-app

# 1. Bad Dockerfile
echo "[Python] Building bad Dockerfile..."
time docker build -t py-bad -f Dockerfile.bad .
echo "Image size py-bad:"
docker images py-bad --format "{{.Size}}"

# 2. Modify code and rebuild bad Dockerfile
echo "[Python] Modifying code and rebuilding bad Dockerfile..."
sed -i.bak 's/msg/message/g' spaceship/routers/api.py
time docker build -t py-bad-mod -f Dockerfile.bad .
echo "Image size py-bad-mod:"
docker images py-bad-mod --format "{{.Size}}"
# Revert
mv spaceship/routers/api.py.bak spaceship/routers/api.py

# 3. Good Dockerfile (first build)
echo "[Python] Building good Dockerfile..."
time docker build -t py-good -f Dockerfile.good .
echo "Image size py-good:"
docker images py-good --format "{{.Size}}"

# Modify code and rebuild good Dockerfile
echo "[Python] Modifying code and rebuilding good Dockerfile..."
sed -i.bak 's/msg/message/g' spaceship/routers/api.py
time docker build -t py-good-mod -f Dockerfile.good .
echo "Image size py-good-mod:"
docker images py-good-mod --format "{{.Size}}"
# Revert
mv spaceship/routers/api.py.bak spaceship/routers/api.py

# 4. Alpine Dockerfile
echo "[Python] Building Alpine Dockerfile..."
time docker build -t py-alpine -f Dockerfile.alpine .
echo "Image size py-alpine:"
docker images py-alpine --format "{{.Size}}"

# 5. Add numpy
echo "numpy" >> requirements/backend.in
cat << 'EOF' >> spaceship/routers/api.py

import numpy as np

@router.get('/matrix')
def matrix() -> dict:
    matrix_a = np.random.rand(10, 10).tolist()
    matrix_b = np.random.rand(10, 10).tolist()
    product = np.dot(matrix_a, matrix_b).tolist()
    return {
        "matrix_a": matrix_a,
        "matrix_b": matrix_b,
        "product": product
    }
EOF

echo "[Python] Building Debian Numpy..."
time docker build -t py-numpy-debian -f Dockerfile.good .
echo "Image size py-numpy-debian:"
docker images py-numpy-debian --format "{{.Size}}"

echo "[Python] Building Alpine Numpy..."
time docker build -t py-numpy-alpine -f Dockerfile.alpine .
echo "Image size py-numpy-alpine:"
docker images py-numpy-alpine --format "{{.Size}}"

cd ..

echo "=== GOLANG EXPERIMENTS ==="
cd golang-app

echo "[Golang] Building Basic..."
time docker build -t go-basic -f Dockerfile.basic .
echo "Image size go-basic:"
docker images go-basic --format "{{.Size}}"

echo "[Golang] Building Scratch..."
time docker build -t go-scratch -f Dockerfile.scratch .
echo "Image size go-scratch:"
docker images go-scratch --format "{{.Size}}"

echo "[Golang] Building Distroless..."
time docker build -t go-distroless -f Dockerfile.distroless .
echo "Image size go-distroless:"
docker images go-distroless --format "{{.Size}}"

cd ..

echo "=== DNS EXPERIMENTS ==="
docker network create dns-lab || true
docker run -d --name dns-server --network dns-lab alpine sh -c "apk add --no-cache dnsmasq && echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && dnsmasq -k --log-queries --log-facility=-"

sleep 2
echo "Resolving from Ubuntu..."
docker run --rm --network dns-lab --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) --dns-search="corp" ubuntu:latest getent hosts myservice.internal || echo "Ubuntu failed or succeeded"

echo "Resolving from Alpine..."
docker run --rm --network dns-lab --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) --dns-search="corp" alpine:latest getent hosts myservice.internal || echo "Alpine failed"

docker rm -f dns-server
docker network rm dns-lab

echo "=== ALL DONE ==="
