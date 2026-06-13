# Nextcloud-opzet & opslagstructuur

> Voor de Opname-app (blueprint collective). Levend document.
> Laatste update: 2026-06-12.

## Wat de app doet
Bij **Afronden en mail** (en via de knop **Upload naar Nextcloud**) uploadt de app
per opname automatisch naar Nextcloud via WebDAV, in deze structuur:

```
<doelmap>/<postcode huisnummer>/
├── foto's/          ← de gemaakte foto's
├── EP/              ← XML-export, formulier-PDF (later: meer formulieren/beslisschema's)
├── correspondentie/ (leeg aangemaakt)
└── onderbouwing/    (leeg aangemaakt)
```

- **Doelmap** is instelbaar in de app (Instellingen → Nextcloud). Leeg = hoofdmap.
- Verbinding via **app-wachtwoord** (Basic auth), versleuteld opgeslagen op het toestel.

---

## Onboarding per adviseur (app instellen)
1. In Nextcloud (browser): **avatar → Persoonlijke instellingen → Beveiliging →
   Apparaten & sessies → "Nieuw app-wachtwoord aanmaken"** (naam bv. "Opname app").
   - ⚠️ Gebruik **dit app-wachtwoord**, niet je gewone inlogwachtwoord
     (met 2FA werkt het gewone wachtwoord niet voor WebDAV).
   - Noteer de **gebruikersnaam** (je inlog-ID; staat ook in het WebDAV-adres
     onderaan Bestanden-instellingen — soms anders dan je weergavenaam).
2. In de app → **Instellingen → Nextcloud**: vul **server-URL**
   (bv. `https://cloud.jouwdomein.nl`), **gebruikersnaam**, **app-wachtwoord** en
   de **doelmap** in → **Verbinden & testen** (moet groen worden).

---

## Centrale opslag voor een groeiend team (~50 adviseurs) — aanrader
Standaard landt alles in de **persoonlijke** opslag van het ingelogde account →
versnipperd. Voor centraal beheer:

**Nextcloud Group Folders (admin-app) + per-adviseur account:**
1. Admin maakt een **groepsmap** (bv. `Opnames`) gekoppeld aan groep "Adviseurs"
   (met quota + rechten). Verschijnt bij elke adviseur onder `/Opnames`.
2. Elke adviseur: **eigen account + eigen app-wachtwoord**, **doelmap = `Opnames`**.
3. → Alle uploads landen **centraal** in dezelfde groepsmap.

**Waarom per-adviseur account (niet één gedeeld account):**
- Toegang per persoon **intrekbaar** bij vertrek (offboarding).
- Herleidbaar wie wat deed.
- Eén gedeeld account = gedeeld wachtwoord = slecht voor beveiliging.

**Aandachtspunten bij schaal:**
- **Botsingen:** twee adviseurs op hetzelfde adres → zelfde `<postcode huisnummer>`-map.
  Oplossen met een extra laag (jaar / adviseur / opdrachtgever) of uniek dossiernr.
- **Quota & bewaarbeleid** op de groepsmap.
- **Rechten:** adviseurs schrijven; kantoor/management leest alles.

---

## Open beslissing (te bespreken — 13-06-2026)
Wil de app het pad automatisch verder opbouwen onder de doelmap? Opties (combineerbaar):
- **Jaar automatisch**: `<doelmap>/2026/<postcode huisnummer>/...`
- **Adviseur automatisch**: veld 'adviseur/initialen' in Instellingen → `<doelmap>/<adviseur>/...`
- **Opdrachtgever/klant**: veld per opname → `<doelmap>/<klant>/...`
- **Niets**: indeling via de doelmap / op Nextcloud zelf.

Gebruiker denkt erover na en kiest in de volgende sessie.
