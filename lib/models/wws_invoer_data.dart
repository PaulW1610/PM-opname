import 'wws_opname_data.dart';

class WwsInvoerData {
  final bool toepassen;
  final String punten;
  final String maxHuur;
  final String wozWaarde;
  final String wozJaar;
  /// Volledige opname-invoer waarmee de puntentelling is berekend.
  final WwsOpnameData? opnameData;

  const WwsInvoerData({
    this.toepassen = false,
    this.punten = '',
    this.maxHuur = '',
    this.wozWaarde = '',
    this.wozJaar = '2026',
    this.opnameData,
  });

  WwsInvoerData copyWith({
    bool? toepassen,
    String? punten,
    String? maxHuur,
    String? wozWaarde,
    String? wozJaar,
    WwsOpnameData? opnameData,
  }) {
    return WwsInvoerData(
      toepassen: toepassen ?? this.toepassen,
      punten: punten ?? this.punten,
      maxHuur: maxHuur ?? this.maxHuur,
      wozWaarde: wozWaarde ?? this.wozWaarde,
      wozJaar: wozJaar ?? this.wozJaar,
      opnameData: opnameData ?? this.opnameData,
    );
  }

  bool get hasInput {
    return punten.trim().isNotEmpty ||
        maxHuur.trim().isNotEmpty ||
        wozWaarde.trim().isNotEmpty;
  }

  String get korteStatus {
    if (!toepassen) {
      return 'WWS: nee';
    }
    if (punten.trim().isNotEmpty) {
      return 'WWS: ja (${punten.trim()} pt)';
    }
    return 'WWS: ja';
  }

  Map<String, dynamic> toJson() => {
        'toepassen': toepassen,
        'punten': punten,
        'maxHuur': maxHuur,
        'wozWaarde': wozWaarde,
        'wozJaar': wozJaar,
        if (opnameData != null) 'opnameData': opnameData!.toJson(),
      };

  factory WwsInvoerData.fromJson(Map<String, dynamic> json) => WwsInvoerData(
        toepassen: json['toepassen'] as bool? ?? false,
        punten: json['punten'] as String? ?? '',
        maxHuur: json['maxHuur'] as String? ?? '',
        wozWaarde: json['wozWaarde'] as String? ?? '',
        wozJaar: json['wozJaar'] as String? ?? '2026',
        opnameData: json['opnameData'] != null
            ? WwsOpnameData.fromJson(
                Map<String, dynamic>.from(json['opnameData'] as Map))
            : null,
      );
}
