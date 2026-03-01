# 12-maanden roadmap: AI-ondersteunde opname (hybride met Leica BLK2GO)

Datum: 28-02-2026
Context: huidige app is stabiel in productieflow; doel is versnellen van opname zonder verlies van controle of kwaliteit.

## Visie
- Sneller en consistenter opnemen met AI-prefill, spraakinvoer en slimme foto-controle.
- BLK2GO blijft referentie voor hoge precisie; app- en brilmetingen worden gefaseerd toegevoegd met confidence en menselijke validatie.
- Doelarchitectuur: hybride veldworkflow (mobiel/bril) + backend AI + kwaliteitscontrole t.o.v. referentiebron.

## Noordster KPI's (12 maanden)
- 30-40% minder tijd per opname.
- >= 60% velden automatisch voorgesteld (prefill).
- <= 10% handmatige correcties op AI-voorstellen na 6 maanden.
- Meetafwijking app t.o.v. BLK2GO binnen vooraf afgesproken bandbreedte per objecttype.
- >= 98% dossier-compleetheid bij eerste oplevering.

## Fase 1 (Q1): Fundament en snelle winst
Doel: AI-assistent zonder meetclaims; focus op snelheid en compleetheid.

### Scope
- AI-fotoherkenning voor objectlabels (raam, deur, meterkast, cv, dakvlak, geveldeel).
- Spraaknotities + intentherkenning (bijv. "zet bij gevel Noord").
- Slimme checklist: ontbrekende foto's/velden signaleren.
- Audittrail per AI-actie: voorstel, gebruiker, tijdstip, bevestiging/wijziging.

### Techniek
- App: workflow-uitbreiding met prefill-voorstellen en 1-tap bevestigen.
- Backend: AI-classificatie/OCR endpoints.
- Data: event logging voor modelverbetering en KPI-dashboard.

### Acceptatiecriteria
- Minimaal 5 objectklassen betrouwbaar herkend.
- Spraakopdrachten met >= 90% intent-correctheid in praktijktest.
- 20% tijdsreductie in pilotteam.

## Fase 2 (Q2): Meten met confidence (mobiel eerst)
Doel: bruikbare veldmetingen met duidelijke onzekerheid en validatie.

### Scope
- iPhone Pro LiDAR metingen voor breedte/hoogte (raam, deur, gevelsegment).
- UI met confidence-indicator (hoog/midden/laag) en verplichte menselijke bevestiging.
- Kalibratie- en validatieflow: vergelijking met handmeting op subset.

### Techniek
- AR-meetlaag met punt-selectie en automatische snapping.
- Regels: meting alleen "akkoord" als opnamecondities voldoen (afstand, hoek, licht).
- Opslag: per meting bron, confidence, operator en eventuele correctie.

### Acceptatiecriteria
- Herhaalbaarheid binnen afgesproken tolerantie op testset.
- >= 80% van metingen direct geaccepteerd zonder heropname.
- Volledige traceerbaarheid voor alle gemeten waarden.

## Fase 3 (Q3): Handsfree uitvoering (smart glasses)
Doel: inspecteur minder schermtijd, meer doorloop op locatie.

### Scope
- Integratie met gekozen bril (praktisch advies: RealWear voor handsfree flow).
- Voice-first taaksturing: "volgende foto", "label als noordgevel", "meet raam".
- Live kwaliteitsfeedback (scherpte, framing, ontbrekend detail).

### Techniek
- Bril als capture/bedieningslaag; rekenwerk op telefoon/backend.
- Synchronisatie met dossiercontext in realtime.
- Failover: offline buffer + later sync.

### Acceptatiecriteria
- 25-30% minder scherminteractie in veldtest.
- >= 95% succesvolle sync van brilcaptured assets.
- Geen regressie op dossierkwaliteit t.o.v. Q2.

## Fase 4 (Q4): BLK2GO-hybride kwaliteitssysteem
Doel: app-meting en AI-output toetsen/kalibreren tegen Leica BLK2GO referentie.

### Scope
- Referentie-import en vergelijking op geselecteerde objecten.
- Automatische afwijkingsrapportage per type meting.
- Model/regel tuning op basis van afwijkingspatronen.

### Techniek
- Vergelijkingspipeline: app-output vs referentie-output.
- Dashboards: afwijking, herkeuringen, oorzaken.
- Governance: periodieke quality gate voor productie-uitrol.

### Acceptatiecriteria
- Meetafwijking per objecttype binnen afgesproken bandbreedte.
- Dalende trend in handmatige correcties per kwartaal.
- Auditproof rapportage voor interne/externe kwaliteitscontrole.

## Tooling- en hardwareadvies
- Korte termijn (0-6 mnd): iPhone Pro LiDAR + huidige app + backend AI.
- Middellange termijn (6-12 mnd): RealWear voor handsfree operatie.
- Leica BLK2GO blijft referentiebron voor precisie-validatie.

## Risico's en mitigaties
- Risico: overschatting AI-meting -> Mitigatie: confidence + verplichte bevestiging.
- Risico: privacy/AVG -> Mitigatie: dataminimalisatie, bewaarbeleid, anonimisatie waar nodig.
- Risico: netwerkproblemen -> Mitigatie: offline first en robuuste retries.
- Risico: adoptie in team -> Mitigatie: korte feedbackloops en training op veldscenario's.

## 90-dagen startplan (direct uitvoerbaar)
1. Kies 1 pilotteam en 10 representatieve opnamecases.
2. Activeer AI-prefill + spraakcommando's voor subset van velden.
3. Meet en publiceer wekelijkse KPI's (tijd, correcties, compleetheid).
4. Voeg LiDAR-meetflow toe voor 2 objecttypen (raam/deur).
5. Beslis op basis van data over brilpilot in volgende fase.

## Definitie van succes na 12 maanden
- Opnameproces aantoonbaar sneller, consistenter en beter voorspelbaar.
- Mens blijft in controle; AI versnelt en standaardiseert.
- Hybride model met BLK2GO levert vertrouwen én schaalbaarheid.
