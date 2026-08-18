# NuaSpa — opis sistema i modula preporuke

**Seminarski rad — Razvoj softvera II**  
**Autor:** Lana Mustafić  
**Verzija:** 9.2 (finalna priprema)  
**Datum:** 18.08.2026.

---

## 1. Svrha i opseg sistema

**NuaSpa** je informacioni sistem za upravljanje spa/wellness centrom. Pokriva cjelokupan poslovni ciklus: katalog tretmana, online rezervacije, raspored terapeuta, plaćanja (Stripe), recenzije, administraciju i **personalizirane preporuke usluga** klijentima.

Sistem je podijeljen u dva repozitorija:

| Repozitorij | Tehnologija | URL |
|-------------|-------------|-----|
| **NuaSpa-App** | Flutter (Android, Windows desktop) | https://github.com/lana-mustafic/NuaSpa-App |
| **NuaSpa-Backend** | ASP.NET Core 9 Web API | https://github.com/lana-mustafic/NuaSpa-Backend |

Klijentska aplikacija komunicira s REST API-jem preko HTTP (preporučeno bez HTTPS u dev/test okruženju zbog self-signed certifikata). Autentifikacija je JWT-based.

---

## 2. Uloge korisnika

| Uloga | Opis | Glavne funkcionalnosti |
|-------|------|------------------------|
| **Klijent** (`Klijent`) | Registrovani korisnik spa centra | Pregled kataloga, favoriti, rezervacije, online plaćanje (mobilno), recenzije, **preporučene usluge**, notifikacije |
| **Terapeut** (`Zaposlenik`) | Zaposlenik koji pruža usluge | Raspored, termini, vlastite usluge, recenzije, profil |
| **Administrator** (`Admin`) | Upravljanje poslovanjem | Kalendar, termini, klijenti, terapeuti, usluge, finansije, izvještaji, resursi, obavijesti |

---

## 3. Tehnološki stack

### Backend
- **.NET 9**, ASP.NET Core Web API
- **SQL Server** + Entity Framework Core 9
- **ASP.NET Core Identity** + JWT Bearer tokeni
- **SignalR** — real-time notifikacije (`/hubs/notifications`)
- **RabbitMQ** + **Worker** servis — asinhrono slanje e-mailova
- **Stripe** — online plaćanje (PaymentIntent, webhook)
- **FluentValidation**, **AutoMapper**, **Swagger**

### Frontend (Flutter)
- **Provider** — state management
- **Dio** — HTTP klijent s JWT interceptorom
- **flutter_secure_storage** — sigurno čuvanje tokena
- **flutter_stripe** — mobilno plaćanje (Android)
- **window_manager** — desktop prozor (Windows)

### Platforme u buildu za predaju
- **Android** — release APK
- **Windows** — desktop release (`runner/Release`)

---

## 4. Arhitektura backend-a

```
NuaSpa.Api          → REST kontroleri, SignalR hub, Swagger
NuaSpa.Application  → poslovna logika, servisi, DTO-ovi
NuaSpa.Domain       → entiteti, enumeracije
NuaSpa.Infrastructure → EF Core migracije
NuaSpa.Worker       → RabbitMQ consumer (e-mail)
```

### Glavni API moduli

| Kontroler | Svrha |
|-----------|--------|
| `Account` | Prijava, refresh, logout, profil, reset lozinke |
| `Rezervacija` | CRUD rezervacija, state machine (Pending → Confirmed → Completed / Cancelled) |
| `Placanje` | Stripe plaćanje, potvrda, refund, webhook |
| `Usluga` / `KategorijaUsluga` | Katalog usluga |
| `Preporuka` | **Preporuke usluga i logiranje signala** |
| `Favorit` | Omiljene usluge klijenta |
| `Recenzija` | Recenzije tretmana |
| `SistemskaNotifikacija` | In-app inbox |
| `Obavijest` | News feed |
| `AdminFinance` / `Izvjestaj` | Finansije i izvještaji |
| `Zaposlenik` / `AdminKlijent` | Upravljanje korisnicima |

---

## 5. Arhitektura klijentske aplikacije

```
lib/
├── main.dart              → AuthWrapper, MobileShell / DesktopShell
├── providers/             → Auth, Notification, Service, MobileNav
├── core/api/              → ApiService, JWT, refresh tokena
├── models/                → DTO modeli
├── screens/
│   ├── catalog/           → katalog, detalji usluge
│   ├── reservations/      → lista i kreiranje rezervacija
│   ├── mobile/            → mobilni home, profil
│   ├── therapist/         → terapeut modul
│   └── admin/             → admin modul
└── ui/layout/             → MobileShell, DesktopShell
```

**Mobilna navigacija:** Home, Services, Book (FAB), Bookings, Profile.  
**Desktop navigacija:** ulogama prilagođen sidebar (Admin / Terapeut / Klijent).

---

## 6. Modul preporuke (recommender)

### 6.1 Cilj

Modul preporuke personalizira prikaz usluga klijentu na osnovu njegovog ponašanja i historije, uz rješenje **cold-start** problema za nove korisnike.

Implementacija: `PreporukaService` (backend), endpointi u `PreporukaController`, prikaz u Flutter katalogu/home ekranu.

### 6.2 Tip algoritma

Kombinacija **content-based filtering (CBF)** i **popularnosti**:

- CBF koristi kategorije usluga i signale ponašanja korisnika
- Za korisnike bez dovoljno signala koristi se **popularnost** (broj rezervacija u zadnjem periodu)

### 6.3 Signali (input)

| Signal | Izvor | Težina |
|--------|-------|--------|
| Rezervacija | Završene/aktivne rezervacije u kategoriji | 4.0 |
| Favorit | Omiljene usluge | 3.0 |
| Pretraga | Tekst pretrage u katalogu | 2.0 |
| Pregled usluge | Otvaranje detalja usluge | 2.0 |
| Popularnost | Globalni broj rezervacija | 1.5 |

Signali se persistiraju u entitet **`KorisnikAktivnost`** (pretraga, pregled). Prozor analize: **90 dana**.

### 6.4 Tok podataka

```
Klijent (Flutter)
    │  GET /api/preporuka/moje
    │  POST /api/preporuka/aktivnost (pretraga / pregled)
    ▼
PreporukaController
    ▼
PreporukaService
    ├── učitaj signale korisnika (rezervacije, favoriti, aktivnosti)
    ├── izračunaj skor po kategoriji/usluzi
    ├── rangiraj usluge
    └── vrati listu s razlogom preporuke (PreporukaRazlogKod)
    ▼
Flutter UI — sekcija "Recommended for you" / slično
```

### 6.5 Razlozi preporuke (objašnjivost)

API vraća kod razloga za svaku preporuku:

| Kod | Značenje |
|-----|----------|
| `FavoriteCategory` | Kategorija odgovara favoritima |
| `PastBookingCategory` | Korisnik je već rezervisao slične usluge |
| `ViewedSimilar` | Pregledao slične usluge |
| `SearchInterest` | Pretraga ukazuje na interes |
| `NewInCategory` | Novo u kategoriji od interesa |
| `Popular` | Popularna usluga (cold-start / fallback) |

### 6.6 Cold-start

Ako korisnik nema dovoljno signala, sistem vraća **popularne usluge** iz posljednjih 90 dana, filtrirane aktivnim uslugama koje korisnik već nije rezervisao u istom danu.

---

## 7. Autentifikacija i autorizacija

1. Korisnik se prijavljuje (`POST /api/account/login`) → JWT access + refresh token.
2. Flutter čuva tokene u **flutter_secure_storage**.
3. Svaki API poziv nosi `Authorization: Bearer {token}`.
4. Pri isteku tokena: automatski refresh; pri neuspjehu — odjava.
5. Uloge u JWT claims određuju vidljivost ekrana i API endpointa.

**Test korisnici (Development seeder):**

| Korisnik | Lozinka | Uloga |
|----------|---------|-------|
| `admin` | `Admin123!` | Admin |
| `lana` | `Lana123!` | Klijent |
| `therapist` | `Therapist123!` | Terapeut |

---

## 8. Konfiguracija i tajne

Konfiguracija se **ne commita** u `.env` datotekama. U repozitoriju se nalaze:

| Datoteka | Sadržaj |
|----------|---------|
| `.env.example` | Predložak varijabli |
| `.env-tajne.zip` | Zaštićena kopija `.env` (ZIP lozinka: **`fit`**) |

### NuaSpa-App (`.env`)
- `API_BASE_URL` — npr. `http://10.0.2.2:5088/api/` (Android emulator) ili `http://127.0.0.1:5088/api/` (Windows)
- `STRIPE_PUBLISHABLE_KEY` — Stripe publishable key

### NuaSpa-Backend (`.env`)
- `ConnectionStrings__DefaultConnection` — SQL Server
- `JwtSettings__Key` — JWT signing key
- `Stripe__SecretKey`, `Stripe__WebhookSecret` — Stripe
- `RabbitMQ__*` — queue za Worker
- `ASPNETCORE_URLS=http://localhost:5088`

**Napomena:** GitHub Release **ne sadrži** `.env` niti druge osjetljive fajlove — samo build artefakte.

---

## 9. Pokretanje iz izvornog koda

### Backend
```bash
cd NuaSpa-Backend
cp .env.example .env   # ili raspakuj .env-tajne.zip (lozinka: fit)
dotnet run --project src/NuaSpa.Api
```
API: `http://localhost:5088` · Swagger (Development): `http://localhost:5088/`

### Flutter klijent
```bash
cd NuaSpa-App
cp .env.example .env   # ili raspakuj .env-tajne.zip (lozinka: fit)
flutter pub get
flutter run --dart-define-from-file=.env
```

### Build za predaju
```bash
# Android APK
flutter build apk --release --dart-define-from-file=.env

# Windows desktop
flutter build windows --release --dart-define-from-file=.env
```

---

## 10. GitHub Release (build za pregled)

Build artefakti se objavljuju kroz **GitHub Releases** repozitorija **NuaSpa-App**, ne kao commit u Git historiji.

**Preporučeni naziv arhive:** `fit-build-2026-08-18.zip`

**Sadržaj ZIP arhive:**

```
NuaSpa-App/build/app/outputs/flutter-apk/app-release.apk
NuaSpa-App/build/windows/x64/runner/Release/   (cijeli folder)
```

**Postupak objave:**
1. Kreirati **Draft** release na GitHub-u
2. Uploadovati ZIP arhivu
3. Provjeriti sadržaj (APK + Windows EXE folder, bez `.env`)
4. Objaviti (Publish) release

Na DL sistem ide **link na tačnu release verziju** (ne na cijeli repozitorij) i **šifra za `.env-tajne.zip`**: `fit`.

---

## 11. Test plan (pregled rada)

| # | Scenarij | Očekivani rezultat |
|---|----------|-------------------|
| 1 | Pokrenuti backend + Windows desktop app | Prijava uspješna |
| 2 | Prijava kao `lana` / `Lana123!` | Klijentski home, katalog, preporuke |
| 3 | Pretraga u katalogu | Signal se logira; preporuke se ažuriraju |
| 4 | Kreiranje rezervacije | Status Pending/Confirmed |
| 5 | Android APK — ista prijava | Mobilni shell, Bookings tab |
| 6 | Stripe test plaćanje (Android) | PaymentIntent flow |
| 7 | Admin `admin` / `Admin123!` | Admin dashboard dostupan |

---

## 12. Zaključak

NuaSpa integriše poslovne procese spa centra s modulom **inteligentnih preporuka** temeljenim na ponašanju korisnika i popularnosti usluga. Arhitektura je modularna (API + Flutter klijent), sigurna (JWT, enkriptovane tajne) i spremna za demonstraciju kroz GitHub Release build paket.
