# Lab 2: Containerization Research

This repository contains the completed research of Lab 2. 
The practical part of Lab2 2 is in [this repository](https://github.com/AnnKuts/2-course-devops/tree/lab2)

## Structure:

- `python-app/`: Contains the FastAPI Python application along with multiple Dockerfiles to demonstrate layer caching and base image tradeoffs.
- `golang-app/`: Contains the Go application to demonstrate multi-stage builds (`scratch` and `distroless`).
- `docs/reports/`: Contains all documentation and analysis:
  - `python_experiments.md`
  - `golang_experiments.md`
  - `dns_experiments.md`
  - `final_report.md`
- `run_experiments.sh`: A bash script to sequentially run all builds and tests to verify the measurements.

## How to run the experiments
To automatically run the builds and get exact execution times and image sizes on your hardware, simply run:

```bash
chmod +x run_experiments.sh
./run_experiments.sh
```
*(Note: Requires a running Docker daemon).*
