# GitHub Actions Self-Hosted Runner (Docker)

Menjalankan GitHub Actions runner di Docker memakai image siap pakai [`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner), tanpa Dockerfile sendiri. Cara pakainya mirip `gitlab-runner`: runner kosong, dan environment job ditentukan lewat `container:` di workflow (padanan `image:` di GitLab).

## Isi

| File | Fungsi |
|------|--------|
| `docker-compose.yml` | Service runner, mount `docker.sock` dan folder kerja |
| `.env.example` | Contoh konfigurasi |
| `Makefile` | Shortcut perintah |

## Prasyarat

- Docker + Docker Compose v2 di server
- `make` (opsional)
- Akses admin ke repo atau organisasi GitHub tujuan

## Langkah 1 - Buat Personal Access Token

1. GitHub → Settings → Developer settings → Personal access tokens.
2. Buat token (classic) dengan scope:
   - Runner untuk **repo**: `repo`
   - Runner untuk **organisasi**: `admin:org`
3. Salin token (`ghp_...`) ke `ACCESS_TOKEN`.

## Langkah 2 - Konfigurasi

```bash
cp .env.example .env
```

Runner untuk satu repo:

```env
RUNNER_SCOPE=repo
REPO_URL=https://github.com/OWNER/REPO
ACCESS_TOKEN=ghp_xxxxxxxxxxxx
```

Runner untuk organisasi:

```env
RUNNER_SCOPE=org
ORG_NAME=nama-org
ACCESS_TOKEN=ghp_xxxxxxxxxxxx
```

| Variabel | Keterangan |
|----------|------------|
| `RUNNER_SCOPE` | `repo` atau `org` |
| `REPO_URL` / `ORG_NAME` | Target runner, sesuai scope |
| `ACCESS_TOKEN` | PAT, dipakai untuk registrasi otomatis |
| `RUNNER_NAME` | Nama runner di GitHub |
| `RUNNER_LABELS` | Label untuk `runs-on` (pisahkan dengan koma) |
| `RUNNER_GROUP` | Runner group (khusus org, opsional) |
| `EPHEMERAL` | Isi `1` agar runner hanya mengerjakan satu job |
| `WORK_DIR` | Folder kerja job, **path sama di host dan container** (default `/opt/github-runner/work`) |
| `RUNNER_IMAGE_TAG` | Tag image, default `latest` |
| `DNS1`, `DNS2` | DNS container |
| `TZ` | Timezone |

## Langkah 3 - Jalankan

```bash
make up
make logs
```

Cek di GitHub: Settings → Actions → Runners. Status runner harus **Idle**.

## Langkah 4 - Pakai di workflow

Seperti `image:` di GitLab, pakai `container:` supaya PHP, Node, dan lainnya tersedia tanpa dipasang manual:

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: [self-hosted, docker]
    container: php:8.3-cli        # setara "image:" di GitLab
    steps:
      - uses: actions/checkout@v4
      - run: php -v
```

Untuk Composer, pakai image yang sudah berisi PHP dan Composer, misalnya `container: composer:2`, atau image kustom Anda.

Tanpa `container:`, job berjalan langsung di dalam container runner, yang tidak berisi PHP atau Node.

Label di `runs-on` harus sama dengan `RUNNER_LABELS`.

## Perintah Makefile

| Perintah | Fungsi |
|----------|--------|
| `make up` | Jalankan runner |
| `make down` | Stop + hapus container |
| `make restart` | `down` lalu `up` |
| `make rebuild` | Pull image terbaru + recreate |
| `make logs` | Ikuti log |
| `make ps` | Status container |
| `make shell` | Masuk ke container |

## Scale (banyak runner)

Hapus `container_name` di `docker-compose.yml`, kosongkan `RUNNER_NAME`, lalu:

```bash
docker compose up -d --scale github-runner=3
```

Beberapa runner berbagi `WORK_DIR` yang sama. Untuk beban berat, lebih aman jalankan stack terpisah dengan `WORK_DIR` berbeda.

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| 404 saat registrasi | `REPO_URL`/`ORG_NAME` salah, atau PAT tidak punya scope/akses yang cukup |
| 401/403 saat registrasi | PAT salah, kedaluwarsa, atau Anda bukan admin repo/org |
| `Could not resolve host` | Set `DNS1`/`DNS2` di `.env`, lalu `make restart` |
| `runner version is out of date` | `make rebuild` untuk menarik image terbaru |
| Job dengan `container:` gagal soal mount/path | Pastikan `WORK_DIR` sama persis di host dan container (sudah di compose) |
| `Access to the path ... is denied` | Folder `WORK_DIR` di host harus bisa ditulis container (`sudo chmod 777 /opt/github-runner/work`, atau pilih folder lain) |
| Runner tampil Offline setelah `make down` | Hapus manual di Settings → Actions → Runners |

## Catatan keamanan

- Container memakai `docker.sock` milik host, sehingga workflow punya akses penuh ke Docker host. Pakai hanya untuk repo yang dipercaya.
- **Jangan** pasang self-hosted runner di repo publik. Pull request dari fork bisa menjalankan kode sembarang di server Anda.
- Jangan commit file `.env` (sudah ada di `.gitignore`).
- Gunakan PAT dengan scope seminimal mungkin dan beri masa kedaluwarsa.
