# WAManager — Client Flutter Mobile & Desktop

Applicazione multipiattaforma (Android, iOS, Web, Windows/macOS) per la gestione della scuola di Tango e l'automazione WhatsApp.

---

## 📱 Caratteristiche Implementate

1. **Autenticazione con Token**: login con credenziali Django e configurazione dell'indirizzo del server.
2. **Elenco Allievi (9b)**: ricerca in tempo reale, raggruppamento per Scuola o Corso, visualizzazione ruoli, livelli e recensioni.
3. **Presenze per Lezione (9c)**: selezione della lezione, modifica manuale checkbox delle presenze con sincronizzazione istantanea, salvataggio batch e generazione automatica coppie (Matching).
4. **Pannello Jolly WhatsApp (9d)**: invio messaggi via WhatsApp per richiedere la disponibilità dei jolly per lezioni specifiche, con selezione per priorità o allievi dedicati.
5. **Pagamenti Trimestrali (9e, 9f)**: registrazione pagamenti per corso e trimestre (default 150€), consultazione con filtri per scuola, corso, trimestre e calcolo totale incassato.
6. **Lezioni & Argomenti (9g, 9h)**: inserimento e consultazione lezioni con argomenti trattati e statistiche presenze.
7. **Prospects (9i)**: gestione prospect con note e azione per iscriverli ai corsi convertendoli in allievi effettivi.
8. **Configurazioni (9a)**: inserimento e gestione di Scuole, Corsi, Argomenti e Jolly.
9. **Layout Responsive**: NavigationRail per desktop/tablet e BottomNavigationBar con Drawer per smartphone.

---

## 🚀 Come Eseguire l'Applicazione

### 1. Prerequisiti
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installato (versione >= 3.0.0).

### 2. Installazione Dipendenze
Dalla cartella `flutter_app/`:
```bash
flutter pub get
```

### 3. Esecuzione su Browser Web (Desktop / Mobile browser)
```bash
flutter run -d chrome
```

### 4. Esecuzione su Dispositivo Android / Emulatore
```bash
flutter run -d android
```
*(Se utilizzi l'emulatore Android, imposta l'URL del backend come `http://10.0.2.2:8000` invece di `localhost`).*

### 5. Compilazione APK Android
```bash
flutter build apk --release
```
L'APK generato si troverà in `build/app/outputs/flutter-apk/app-release.apk` pronto per essere installato su qualsiasi smartphone Android.
