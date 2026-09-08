/// Datamodel voor het WWS-onzelfstandig-dossier (kamerverhuur). De SERVER
/// rekent (`POST /bd/v1/wws-onz`); dit model bouwt alleen het invoer-JSON zoals
/// de tool het verwacht (zie REGELS.md §2 + testdossier.json). `toJson` levert
/// exact dat formaat.
library;

/// Keuzelijsten (letterlijk uit REGELS.md — de server matcht hierop).
class WwsOnzKeuzes {
  static const List<String> ruimtetypes = [
    'Woonkamer',
    'Woonkamer met open keuken',
    'Keuken',
    'Badkamer',
    'Toiletruimte',
    'Berging/overig',
    'Verkeersruimte',
  ];

  static const List<String> soorten = [
    'Vertrek',
    'Overige ruimte',
    'Verkeersruimte',
  ];

  static const List<String> aanrechtlengtes = [
    'Korter dan 1 meter',
    'Tussen de 1 en 2 meter',
    'Tussen de 2 en 3 meter',
    'Langer dan 3 meter',
    'Langer dan 5 meter alleen bij 8 of meer huisgenoten',
  ];

  static const List<String> keukenKenmerken = [
    'Inbouw afzuiginstallatie',
    'Inbouw kookplaat inductie',
    'Inbouw kookplaat keramisch',
    'Inbouw kookplaat gas',
    'Inbouw koelkast',
    'Inbouw vrieskast',
    'Kokend waterfunctie',
    'Inbouw oven elektrisch',
    'Inbouw oven gas',
    'Inbouw magnetron',
    'Inbouw vaatwasmachine',
    'Extra kastruimte boven minimum per 60 cm',
    'Eenhandsmengkraan',
    'Thermostatische mengkraan',
  ];

  static const List<String> sanitairBasis = [
    'Toilet in aparte ruimte',
    'Toilet in badkamer',
    'Hangend toilet in aparte ruimte',
    'Hangend toilet in badkamer',
    'Wastafel',
    'Meerpersoonswastafel',
    'Douche',
    'Bad',
    'Bad/douche',
  ];

  static const List<String> sanitairExtra = [
    'Bubbelfunctie van het bad',
    'Gemonteerde volledige afscheiding van de douche',
    'Handdoekenradiator',
    'Ingebouwd kastje met in- of opgebouwde wastafel',
    'Kastruimte',
    'Stopcontact bij wastafel',
    'Eenhandsmengkraan',
    'Thermostatische mengkraan',
  ];

  static const List<String> buitenTypes = [
    'Geen buitenruimte',
    'Tuin',
    'Balkon',
    'Dakterras',
    'Patio',
    'Buitenruimte',
  ];

  static const List<String> keukenSoort = ['Gedeelde keuken', 'Eigen keuken'];

  static const List<String> sanitairSoort = [
    'Gedeeld sanitair',
    'Eigen toilet, douche en wastafel',
  ];

  static const List<String> energielabels = [
    'A++++',
    'A+++',
    'A++',
    'A+',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'Geen geldig label',
  ];

  static const List<String> aftrekposten = [
    'Vertrekken minder dan 8 m2',
    'Bereikbaar via woon-/slaapvertrek verhuurder',
    'Ruitoppervlakte hoofdwoonvertrek minder dan 0,75 m2',
    'Laagste raamkozijn hoger dan 1,60 m',
  ];

  /// COROP-gebieden (sleutels COROP_WOZ_2026, REGELS.md §3.11).
  static const List<String> coropGebieden = [
    'Oost-Groningen', 'Delfzijl en omgeving', 'Overig Groningen',
    'Noord-Friesland', 'Zuidwest-Friesland', 'Zuidoost-Friesland',
    'Noord-Drenthe', 'Zuidoost-Drenthe', 'Zuidwest-Drenthe',
    'Noord-Overijssel', 'Zuidwest-Overijssel', 'Twente', 'Veluwe',
    'Achterhoek', 'Arnhem/Nijmegen', 'Zuidwest-Gelderland', 'Utrecht',
    'IJmond', 'Zaanstreek', 'Het Gooi en Vechtstreek',
    "Agglomeratie 's-Gravenhage", 'Delft en Westland', 'Oost-Zuid-Holland',
    'Groot-Rijnmond', 'Zuidoost-Zuid-Holland', 'Zeeuwsch-Vlaanderen',
    'Overig Zeeland', 'West-Noord-Brabant', 'Midden-Noord-Brabant',
    'Noordoost-Noord-Brabant', 'Zuidoost-Noord-Brabant', 'Noord-Limburg',
    'Midden-Limburg', 'Zuid-Limburg', 'Flevoland', 'Kop van Noord-Holland',
    'Alkmaar en omgeving', 'Agglomeratie Haarlem', 'Groot-Amsterdam',
    'Agglomeratie Leiden en Bollenstreek',
  ];
}

/// Eén ruimte (privéruimte van een kamer, of extra gedeelde ruimte).
class WwsOnzRuimte {
  String naam;
  String soort;
  double oppervlakte;
  bool gedeeld;
  int delenMet;
  bool verwarmd;
  bool verkoeld;

  WwsOnzRuimte({
    this.naam = '',
    this.soort = 'Vertrek',
    this.oppervlakte = 0,
    this.gedeeld = false,
    this.delenMet = 1,
    this.verwarmd = true,
    this.verkoeld = false,
  });

  Map<String, dynamic> toJson() => {
        'Naam': naam,
        'Soort': soort,
        'Oppervlakte m2': oppervlakte,
        'Gedeeld': gedeeld,
        'Delen met': delenMet,
        'Verwarmd': verwarmd,
        'Verkoeld': verkoeld,
      };
}

/// Gedeelde ruimte met kenmerken (`shared_facility_rows`).
class WwsOnzFacilityRij {
  String naam;
  String ruimtetype;
  double oppervlakte;
  bool gedeeld;
  int delenMet;
  bool verwarmd;
  bool verkoeld;
  String aanrecht;
  Map<String, int> keukenKenmerken;
  Map<String, int> sanitairBasis;
  Map<String, int> sanitairExtra;

  WwsOnzFacilityRij({
    this.naam = '',
    this.ruimtetype = 'Woonkamer',
    this.oppervlakte = 0,
    this.gedeeld = true,
    this.delenMet = 1,
    this.verwarmd = true,
    this.verkoeld = false,
    this.aanrecht = 'Korter dan 1 meter',
    Map<String, int>? keukenKenmerken,
    Map<String, int>? sanitairBasis,
    Map<String, int>? sanitairExtra,
  })  : keukenKenmerken = keukenKenmerken ?? {},
        sanitairBasis = sanitairBasis ?? {},
        sanitairExtra = sanitairExtra ?? {};

  Map<String, dynamic> toJson() => {
        '_id': 'x',
        'Naam': naam,
        'Ruimtetype': ruimtetype,
        'Oppervlakte m2': oppervlakte,
        'Gedeeld': gedeeld,
        'Delen met': delenMet,
        'Verwarmd': verwarmd,
        'Verkoeld': verkoeld,
        'Aanrecht': aanrecht,
        'Keuken basis': <String, int>{},
        'Keuken kenmerken': keukenKenmerken,
        'Sanitair basis': sanitairBasis,
        'Sanitair extra': sanitairExtra,
      };
}

/// Buitenruimte op pandniveau (`outdoor`).
class WwsOnzBuiten {
  String naam;
  String type;
  double oppervlakte;
  bool gedeeld;
  int delenMet;

  WwsOnzBuiten({
    this.naam = '',
    this.type = 'Tuin',
    this.oppervlakte = 0,
    this.gedeeld = false,
    this.delenMet = 1,
  });

  Map<String, dynamic> toJson() => {
        'Naam': naam,
        'Type': type,
        'Oppervlakte m2': oppervlakte,
        'Gedeeld': gedeeld,
        'Delen met': delenMet,
      };
}

/// Eén kamer/unit met eigen voorzieningen.
class WwsOnzKamer {
  String naam;
  String kitchen;
  String privateCountertop;
  Map<String, int> privateKitchenFeatures;
  String sanitary;
  Map<String, int> privateSanitairBasis;
  Map<String, int> privateSanitairExtra;
  bool privateWashbasin;
  String privateOutdoorType;
  double privateOutdoorM2;
  double handicapCosts;
  List<String> deductions;
  bool zorgwoning;
  List<WwsOnzRuimte> rooms;

  WwsOnzKamer({
    this.naam = '',
    this.kitchen = 'Gedeelde keuken',
    this.privateCountertop = 'Korter dan 1 meter',
    Map<String, int>? privateKitchenFeatures,
    this.sanitary = 'Gedeeld sanitair',
    Map<String, int>? privateSanitairBasis,
    Map<String, int>? privateSanitairExtra,
    this.privateWashbasin = false,
    this.privateOutdoorType = 'Geen buitenruimte',
    this.privateOutdoorM2 = 0,
    this.handicapCosts = 0,
    List<String>? deductions,
    this.zorgwoning = false,
    List<WwsOnzRuimte>? rooms,
  })  : privateKitchenFeatures = privateKitchenFeatures ?? {},
        privateSanitairBasis = privateSanitairBasis ?? {},
        privateSanitairExtra = privateSanitairExtra ?? {},
        deductions = deductions ?? [],
        rooms = rooms ?? [WwsOnzRuimte(naam: 'Kamer')];

  Map<String, dynamic> toJson() => {
        '_id': 'u',
        'naam': naam,
        'kitchen': kitchen,
        'sanitary': sanitary,
        'private_countertop': privateCountertop,
        'private_kitchen_features': privateKitchenFeatures,
        'private_sanitary_basis': privateSanitairBasis,
        'private_sanitary_extra': privateSanitairExtra,
        'private_washbasin': privateWashbasin,
        'private_outdoor_type': privateOutdoorType,
        'private_outdoor_m2': privateOutdoorM2,
        'extra_kitchen_points': 0.0,
        'extra_sanitary_points': 0.0,
        'handicap_costs': handicapCosts,
        'video_doorbell': false,
        'deductions': deductions,
        'zorgwoning': zorgwoning,
        'rooms': rooms.map((r) => r.toJson()).toList(),
      };
}

/// Het volledige dossier.
class WwsOnzDossier {
  // building
  String adres;
  String postcode;
  String plaats;
  int? bouwjaar;
  double gbo;
  double woz;
  int occupants;
  String corop;
  String label;
  double parkingPoints;
  bool sharedDoorbellIntercom;
  int heatedHallCount;

  List<WwsOnzFacilityRij> facilityRows;
  List<WwsOnzRuimte> sharedRooms;
  List<WwsOnzBuiten> outdoor;
  List<WwsOnzKamer> units;

  WwsOnzDossier({
    this.adres = '',
    this.postcode = '',
    this.plaats = '',
    this.bouwjaar,
    this.gbo = 0,
    this.woz = 0,
    this.occupants = 1,
    this.corop = 'Utrecht',
    this.label = 'Geen geldig label',
    this.parkingPoints = 0,
    this.sharedDoorbellIntercom = false,
    this.heatedHallCount = 0,
    List<WwsOnzFacilityRij>? facilityRows,
    List<WwsOnzRuimte>? sharedRooms,
    List<WwsOnzBuiten>? outdoor,
    List<WwsOnzKamer>? units,
  })  : facilityRows = facilityRows ?? [],
        sharedRooms = sharedRooms ?? [],
        outdoor = outdoor ?? [],
        units = units ?? [WwsOnzKamer(naam: 'Kamer 1')];

  Map<String, dynamic> toJson() => {
        'tool_type': 'wws_onzelfstandige_woonruimte',
        'version': 1,
        'building': {
          'adres': adres,
          'postcode': postcode,
          'plaats': plaats,
          if (bouwjaar != null) 'bouwjaar': bouwjaar,
          'gbo': gbo,
          'woz': woz,
          'occupants': occupants,
          'corop': corop,
          'label': label,
          'ep2': null,
          'parking_points': parkingPoints,
          'shared_doorbell_intercom': sharedDoorbellIntercom,
          'shared_facilities': {
            'heated_hall_count': heatedHallCount,
          },
        },
        'shared_facility_rows': facilityRows.map((r) => r.toJson()).toList(),
        'shared_rooms': sharedRooms.map((r) => r.toJson()).toList(),
        'outdoor': outdoor.map((r) => r.toJson()).toList(),
        'units': units.map((u) => u.toJson()).toList(),
      };
}
