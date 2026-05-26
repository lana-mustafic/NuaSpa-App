# NuaSpa App (Flutter)

Klijentska aplikacija za NuaSpa spa management sistem — desktop (Windows/macOS/Linux) i mobilni (Android/iOS) shell.

## Preduvjeti

- Flutter SDK ^3.11
- Pokrenut [NuaSpa Backend](../NuaSpa-Backend) API (default: `http://localhost:5088`)

## Konfiguracija

Kopiraj `.env.example` u `.env` i prilagodi vrijednosti:

```bash
cp .env.example .env
```

| Varijabla | Opis |
|-----------|------|
| `API_BASE_URL` | Base URL API-ja, npr. `http://127.0.0.1:5088/api/` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key (mobilno plaćanje) |

## Pokretanje

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

Android emulator koristi `http://10.0.2.2:5088/api/` umjesto `127.0.0.1`.

## Uloge i funkcionalnosti

- **Klijent** — katalog, rezervacije, Stripe plaćanje (Android/iOS), notifikacije, obavijesti
- **Terapeut** — raspored, termini, recenzije
- **Admin** — kalendar, termini, finansije, klijenti, usluge, notifikacije

## API sloj

Svi HTTP pozivi idu kroz `lib/core/api/services/api_service.dart` (Dio + JWT iz `ApiClient`).

Notifikacije se automatski osvježavaju pollingom (15 s) preko `NotificationProvider`.

## Testovi

```bash
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:5088/api/
```

## Repozitorij

Backend: [NuaSpa-Backend](https://github.com/lana-mustafic/NuaSpa-Backend)
