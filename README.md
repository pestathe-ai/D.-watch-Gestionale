# D. Watch Gestionale

App Android per gestire acquisti, vendite, spese, ordini e la propria collezione
di orologi. Un'app Dom Studio.

## Novità v0.1
- **Contatori per anno solare**: scegli l'anno in alto (o "Tutti"). Un acquisto conta
  nell'anno della sua data, una vendita nell'anno di vendita, una spesa nell'anno della spesa.
- **Mia collezione**: i pezzi che tieni, divisi per anno di ingresso, con costo e valore stimato.
  Restano fuori da vendite e netto.
- **Statistiche**: riepilogo, confronto con l'anno precedente, vendite per profilo (chi ha
  venduto), per piattaforma e mese per mese.
- **Profili** illimitati, **ordini** con link di tracking, **vendita veloce**.
- **Backup JSON** compatibile con quello della versione web.

## Limiti noti
- I dati restano solo sul telefono: esporta un backup ogni tanto.
- Niente foto dei pezzi (previste in una versione successiva).
- Non ancora provata su un telefono reale: la compilazione e i test dei calcoli girano su GitHub.

## Sviluppo
`tool/setup_platforms.sh` genera la cartella `android/`. La CI compila e firma gli APK
(`.github/workflows/build-apk.yml`) e li pubblica nelle Releases.
