# GitHub Actions Self-Hosted Runner (Docker)

Menjalankan GitHub Actions runner di dalam container Docker. Struktur dan perintahnya dibuat mirip dengan `gitlab-runner`.

## Isi

| File | Fungsi |
|------|--------|
| `Dockerfile` | Image Ubuntu 24.04 + runner resmi GitHub + docker CLI/buildx/compose |
| `entrypoint.sh` | Ambil token, register runner, jalankan, unregister saat stop |
| `docker-compose.yml` | Definisi service, mount `docker.sock`, volume `_work` |
| `.env.example` | Contoh konfigurasi |
| `Makefile` | Shortcut perintah |

## Prasyarat

- Docker + Docker Compose v2 di server
- `make` (opsional, bisa pakai `docker compose` langsung)
- Akses admin ke repo atau organisasi GitHub tujuan

## Langkah 1 - Siapkan token

Pilih salah satu.

### Opsi A: Personal Access Token (disarankan)

Token registrasi diambil otomatis setiap container start, jadi aman di-restart kapan saja.

1. GitHub → Settings → Developer settings → Personal access tokens.
2. Buat token (classic) dengan scope:
   - Runner untuk **repo**: `repo`
   - Runner untuk **organisasi**: `admin:org`
3. Salin token (`ghp_...`) ke `ACCESS_TOKEN`.

### Opsi B: Registration token manual

1. Buka repo (atau org) → Settings → Actions → Runners → **New self-hosted runner**.
2. Salin nilai setelah `--token` ke `REGISTRATION_TOKEN`.

Token ini **kedaluwarsa dalam 1 jam** dan hanya cukup untuk start pertama. Setelah runner terdaftar, konfigurasinya tersimpan di dalam container. Jika container di-recreate, Anda butuh token baru.

## Langkah 2 - Konfigurasi

```bash
cp .env.example .env
```

Edit `.env`:

```env
GITHUB_URL=https://github.com/OWNER/REPO     # atau https://github.com/ORG
ACCESS_TOKEN=ghp_xxxxxxxxxxxx
RUNNER_NAME=self-hosted-runner
RUNNER_LABELS=self-hosted,docker
```

| Variabel | Keterangan |
|----------|------------|
| `GITHUB_URL` | URL repo atau organisasi (wajib) |
| `ACCESS_TOKEN` | PAT, untuk token registrasi otomatis |
| `REGISTRATION_TOKEN` | Alternatif manual dari ACCESS_TOKEN |
| `RUNNER_NAME` | Nama runner yang tampil di GitHub |
| `RUNNER_LABELS` | Label, dipakai di `runs-on` (pisahkan dengan koma) |
| `RUNNER_GROUP` | Runner group (khusus organisasi, opsional) |
| `EPHEMERAL` | Isi `1` agar runner hanya mengerjakan satu job lalu hilang |
| `RUNNER_VERSION` | Versi runner, default `latest` (minimal 2.329.0), lihat [rilis actions/runner](https://github.com/actions/runner/releases) |
| `TZ` | Timezone, default `Asia/Jakarta` |

## Langkah 3 - Jalankan

```bash
make up      # build image + start container
make logs    # pantau log
```

Log yang menandakan sukses:

```
√ Runner successfully added
√ Runner connection is good
Listening for Jobs
```

Cek di GitHub: Settings → Actions → Runners. Status runner harus **Idle**.

## Langkah 4 - Pakai di workflow

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: [self-hosted, docker]
    steps:
      - uses: actions/checkout@v4
      - run: docker version
      - run: echo "Jalan di self-hosted runner"
```

Label di `runs-on` harus sama dengan `RUNNER_LABELS`.

## Perintah Makefile

| Perintah | Fungsi |
|----------|--------|
| `make up` | Build + jalankan runner |
| `make down` | Stop + hapus container (runner otomatis di-unregister) |
| `make restart` | `down` lalu `up` |
| `make rebuild` | Build ulang tanpa cache + recreate |
| `make logs` | Ikuti log |
| `make ps` | Status container |
| `make shell` | Masuk ke container |

## Scale (banyak runner)

Hapus baris `container_name` di `docker-compose.yml`, kosongkan `RUNNER_NAME` agar memakai hostname unik, lalu:

```bash
docker compose up -d --scale github-runner=3
```

## Update versi runner

Dengan `RUNNER_VERSION=latest`, cukup jalankan `make rebuild` untuk mendapat rilis terbaru. Atau isi versi tertentu di `.env` lalu `make rebuild`.

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `GITHUB_URL wajib diisi` | Isi `GITHUB_URL` di `.env` |
| `Isi ACCESS_TOKEN atau REGISTRATION_TOKEN` | Isi salah satu token di `.env` |
| HTTP 404 saat ambil token | `GITHUB_URL` salah, atau PAT tidak punya scope/akses ke repo atau org tersebut |
| HTTP 401/403 saat ambil token | PAT salah atau kedaluwarsa, atau Anda bukan admin repo/org |
| `Http response code: NotFound ... registration` | Registration token sudah lebih dari 1 jam, ambil yang baru atau pakai `ACCESS_TOKEN` |
| `Libicu's dependencies is missing` | Pastikan `libicu74` ada di Dockerfile, lalu `make rebuild` |
| `Could not resolve host: api.github.com` | DNS container bermasalah. Set `DNS1`/`DNS2` di `.env` (default 1.1.1.1 / 8.8.8.8), lalu `make restart` |
| `runner version is out of date` / 404 di `runner-registration` | Versi runner terlalu lama. Set `RUNNER_VERSION=latest` lalu `make rebuild` |
| Runner tampil Offline setelah `make down` | Unregister gagal. Hapus manual di Settings → Actions → Runners |
| `permission denied` ke docker.sock | Pastikan `/var/run/docker.sock` ada di host dan di-mount (sudah di compose) |
| Runner lama dengan nama sama | Entrypoint memakai `--replace`, jadi nama yang sama akan menggantikannya |

## Catatan keamanan

- Container memakai `docker.sock` milik host, sehingga workflow punya akses penuh ke Docker host. Pakai hanya untuk repo yang dipercaya.
- **Jangan** pasang self-hosted runner di repo publik. Pull request dari fork bisa menjalankan kode sembarang di server Anda.
- Jangan commit file `.env` (sudah ada di `.gitignore`).
- Gunakan PAT dengan scope seminimal mungkin dan beri masa kedaluwarsa.
