class WwsInvoerData {
  final bool toepassen;
  final String punten;
  final String maxHuur;
  final String wozWaarde;
  final String wozJaar;

  const WwsInvoerData({
    this.toepassen = false,
    this.punten = '',
    this.maxHuur = '',
    this.wozWaarde = '',
    this.wozJaar = '2026',
  });

  WwsInvoerData copyWith({
    bool? toepassen,
    String? punten,
    String? maxHuur,
    String? wozWaarde,
    String? wozJaar,
  }) {
    return WwsInvoerData(
      toepassen: toepassen ?? this.toepassen,
      punten: punten ?? this.punten,
      maxHuur: maxHuur ?? this.maxHuur,
      wozWaarde: wozWaarde ?? this.wozWaarde,
      wozJaar: wozJaar ?? this.wozJaar,
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
}
