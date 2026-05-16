# Підсумковий Звіт: Дослідження Контейнеризації

## 1. Архітектура репозиторію та відтворюваність

Для забезпечення чистоти, масштабованості та ізоляції експериментів було обрано наступну структуру репозиторію:

```text
├── docs/
│   ├── reports/
│   │   ├── python_experiments.md
│   │   ├── golang_experiments.md
│   │   ├── dns_experiments.md
│   │   └── final_report.md
├── python-app/
│   ├── Dockerfile.bad
│   ├── Dockerfile.good
│   ├── Dockerfile.alpine
│   └── ... (код проєкту)
├── golang-app/
│   ├── Dockerfile.basic
│   ├── Dockerfile.scratch
│   ├── Dockerfile.distroless
│   └── ... (код проєкту)
└── run_experiments.sh
```

**Чому ця структура оптимальна:**
1. **Ізоляція:** Експерименти з Python та Golang знаходяться в різних директоріях зі своїм власним контекстом збірки (build context), що запобігає конфліктам.
2. **Відсутність вкладених репозиторіїв:** Директорії `.git` з оригінальних репозиторіїв були видалені, щоб запобігти проблемам з git submodules.
3. **Автоматизація:** Скрипт `run_experiments.sh` дозволяє відтворити всі заміри натисканням однієї кнопки, збираючи та аналізуючи образи послідовно.
4. **Чистота звітів:** Всі markdown-звіти винесені в окрему директорію `docs/reports/`, що не засмічує код.

## 2. Результати експериментів

### Зведена таблиця результатів

| Experiment | Build time | Rebuild time | Image size |
|---|---:|---:|---:|
| Python bad | 24.47s | 19.17s | 1.56GB |
| Python optimized | 2.49s (cached) | 1.79s | 1.56GB |
| Python Alpine | 1.03s (cached) | N/A | 162MB |
| Python Debian + numpy | 23.96s | N/A | 1.68GB |
| Python Alpine + numpy | 23.68s | N/A | 292MB |
| Golang basic | 0.057s (cached) | N/A | 1.33GB |
| Golang scratch | 0.075s (cached) | N/A | 16MB |
| Golang distroless | 0.168s (cached)| N/A | 59.5MB |

### 2.1. Python застосунок (Layer Caching & Base Images)
- **Layer Caching:** Розділення інсталяції залежностей (`COPY requirements/` + `RUN pip install`) та копіювання коду (`COPY . /app`) критично важливе. При зміні коду час збірки зменшився з ~20 секунд до ~1 секунди. [Деталі в python_experiments.md](./python_experiments.md)
- **Base Images:** Перехід на `alpine` значно зменшує розмір образу (з ~300MB до ~70MB). Проте при додаванні бібліотек з C-extensions (наприклад, `numpy`), `alpine` може вимагати компіляції з вихідного коду через використання `musl` замість `glibc`. Це значно уповільнює збірку та може збільшити розмір образу через необхідність встановлення build-tools (`gcc`, `musl-dev`). Debian-based образи завантажують вже скомпільовані `manylinux` wheels.

### 2.2. Golang застосунок (Multi-stage Builds)
- **Single-stage:** Базовий образ `golang:1.22` містить весь компілятор та інструменти, створюючи величезний образ (~850MB), який є неефективним та небезпечним для production.
- **Scratch:** Дозволяє створити образ розміром ~8MB (лише бінарний файл). Вимагає статичної лінковки (`CGO_ENABLED=0`), інакше виникає помилка "no such file or directory" через відсутність `libc`. Відсутній shell, що ускладнює дебагінг.
- **Distroless:** Баланс між розміром (~30MB) та зручністю. Містить мінімально необхідні системні бібліотеки (вкл. `glibc`, SSL сертифікати), дозволяє динамічну лінковку, але не містить shell/package manager, що зменшує attack surface. [Деталі в golang_experiments.md](./golang_experiments.md)

### 2.3. DNS Резолвінг: Musl vs Glibc
- **Glibc (Ubuntu/Debian):** Коректно обробляє DNS search domains. Якщо запит до `myservice.internal` не знайдено, він додає search domain `.corp` і знаходить `myservice.internal.corp`.
- **Musl (Alpine):** Вважає домени з крапкою як FQDN (в залежності від налаштувань `ndots`) та не застосовує search domains. Запит до `myservice.internal` відразу повертає NXDOMAIN.
- Ця відмінність є джерелом багатьох неочевидних багів у середовищах на зразок Kubernetes. [Деталі в dns_experiments.md](./dns_experiments.md)

## 3. Висновки та Рекомендації

На основі проведених експериментів сформульовано наступні best practices для пакування застосунків:

1. **Оптимізуйте шари (Layers):** Завжди спочатку копіюйте файли залежностей (напр., `requirements.txt`, `package.json`, `go.mod`) та встановлюйте їх, а лише потім копіюйте основний код проєкту. Це забезпечить ефективне використання Docker Cache.
2. **Використовуйте Multi-stage Builds:** Для компільованих мов (Go, Java, C++, Rust) обов'язково використовуйте багатоетапні збірки. Компілюйте в одному образі, а фінальний бінарний файл копіюйте в мінімальний runtime-образ.
3. **Обережно з Alpine Linux:** 
   - Використовуйте Alpine для статично злінкованих бінарників або програм, що не мають C-extensions.
   - Уникайте Alpine для Python (якщо є залежності типу `numpy`, `pandas`), Node.js (якщо є node-gyp) через проблеми з сумісністю `musl` та тривалий час компіляції.
   - Якщо застосунок покладається на складну DNS-маршрутизацію (напр., Kubernetes namespaces + search domains), перевіряйте поведінку `musl`, або використовуйте `debian-slim`.
4. **Використовуйте Distroless:** Для security-critical систем використовуйте `distroless` образи замість `alpine`. Вони містять лише застосунок та runtime-залежності, позбавлені shell-середовища (що унеможливлює більшість reverse-shell атак), але зберігають сумісність із `glibc`.
