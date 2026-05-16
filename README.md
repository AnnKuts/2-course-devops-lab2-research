# DevOps Lab 2: Containerization Research

This repository contains the completed research portion of Laboratory Work No. 2 on Containerization.

## Structure

The project has been architected to isolate experiments while avoiding nested git repositories and maintaining clear, reproducible artifacts:

- **`python-app/`**: Contains the FastAPI Python application along with multiple Dockerfiles to demonstrate layer caching and base image tradeoffs.
- **`golang-app/`**: Contains the Go application to demonstrate multi-stage builds (`scratch` and `distroless`).
- **`docs/reports/`**: Contains all documentation and analysis:
  - `python_experiments.md`
  - `golang_experiments.md`
  - `dns_experiments.md`
  - `final_report.md`
- **`run_experiments.sh`**: A bash script to sequentially run all builds and tests to verify the measurements.

## How to run the experiments

To automatically run the builds and get exact execution times and image sizes on your hardware, simply run:

```bash
chmod +x run_experiments.sh
./run_experiments.sh
```

*(Note: Requires a running Docker daemon).*

## Implementation Details

All requirements outlined in `docs/requirements/lab2.md` have been fulfilled:
- Analyzed optimal project structure and cleaned `.git` folders.
- Implemented and evaluated layer cache usage in Python builds.
- Added `numpy` dependency and endpoint to compare `alpine` vs `debian` native compilation behaviors.
- Analyzed and documented differences in DNS resolution between `glibc` (Ubuntu) and `musl` (Alpine).
- Executed multi-stage builds for Golang using `scratch` (addressing static linking) and `distroless` base images.
- Generated technical markdown reports without boilerplate text.

> **Note on Practical Part:**
> The requirement states: *"Артефактом практичної частини має бути файл docker-compose.yml в репозиторії з виконанням першої лабораторної роботи."*
> As per instructions, the `docker-compose.yml` for Lab 1 services should be pushed to the **Lab 1 repository**. This repository strictly focuses on the **research** portion of Lab 2.
