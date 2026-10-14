# Changelog

Tutte le modifiche rilevanti a questo progetto saranno documentate in questo file.
Il formato è basato su [Keep a Changelog](https://keepachangelog.com/it-IT/1.0.0/), e questo progetto rispetta il [Semantic Versioning](https://semver.org/).

## [1.0.2] - 2026-10-01
### Added
- Aggiunta funzionalit "Esporta Elenco" in formato PDF all'interno della gestione Corsi, che genera un riepilogo tabellare con i dettagli di iscritti e prospect e le metriche sintetiche del corso.

### Changed
- All'apertura della schermata "Presenze", il sistema seleziona ora automaticamente la lezione temporalmente pi vicina ad oggi, migliorando l'accessibilit immediata.
- Nel menu a tendina "Scegli altra lezione", le lezioni gi passate sono state spostate in fondo alla lista per privilegiare l'accesso rapido a quelle future o odierne.
- Rimossa la funzionalit "PDF Appello" dalla schermata delle Presenze, sostituita dal nuovo report PDF a livello di corso.

## [1.0.1] - 2026-10-01
### Added
- Aggiunta configurazione completa per containerizzazione tramite Docker (`docker-compose.yml`, `Dockerfile` per frontend e gateway, `.dockerignore`).
- Aggiunto fallback per preservare l'uso del database `db.sqlite3` anche nell'ambiente containerizzato in produzione.
- Aggiunto endpoint provvisorio per il webhook (`whatsapp_message_webhook`) per prevenire crash del server.

### Changed
- **UI/UX Branding:** I colori principali dell'applicazione sono stati aggiornati a Bordeaux (`#8B2529`) e Beige (`#EBE5DA`).
- **Logo:** L'icona standard della nota musicale è stata sostituita con il logo "TantoTango" personalizzato (nella schermata di login e nel menu di navigazione).
- **Testi:** Rinominati i riferimenti visivi da "WAManager" a "TantoTango Manager - Gestionale scuola di ballo".
- **API Port:** Riallineata l'esposizione della porta del backend nel `docker-compose.yml` alla porta `8082` per mantenere il 100% di compatibilità con lo script di avvio locale `run_desktop.ps1`.

### Fixed
- Risolto errore di avvio di Django (`AttributeError` nel caricamento di `whatsapp_message_webhook`).
- Risolto il fallimento del login nell'app Flutter locale ripristinando il corretto indirizzamento della porta `8082`.

## [1.0.0] - 2026-10-01
### Added
- Baseline del progetto WAManager (TantoTango Manager).
- Funzionalità core di backend (Django) per la gestione di Allievi, Corsi, Scuole, Presenze, Pagamenti, Messaggistica automatica e Jolly.
- Gateway WhatsApp (Node.js/Baileys) per l'invio e ricezione di messaggi/sondaggi.
- Frontend Desktop (Flutter Web).
- Integrazione con servizi di Intelligenza Artificiale per suggerimenti e interpretazione dei dati.
- Avvio semplificato tramite `run_desktop.ps1`.
