class Word {
  final int id;
  final String englishWord;
  final String partOfSpeech;
  final String englishPhonetic;
  final String khmerPhonetic;
  final String khmerDef;

  Word({
    required this.id,
    required this.englishWord,
    required this.partOfSpeech,
    required this.englishPhonetic,
    required this.khmerPhonetic,
    required this.khmerDef,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      englishWord: json['englishWord'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      englishPhonetic: json['englishPhonetic'] as String? ?? '',
      khmerPhonetic: json['khmerPhonetic'] as String? ?? '',
      khmerDef: json['khmerDef'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'englishWord': englishWord,
      'partOfSpeech': partOfSpeech,
      'englishPhonetic': englishPhonetic,
      'khmerPhonetic': khmerPhonetic,
      'khmerDef': khmerDef,
    };
  }
}