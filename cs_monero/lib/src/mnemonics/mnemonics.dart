import 'monero/chinese_simplified.dart';
import 'monero/dutch.dart';
import 'monero/english.dart' as monero;
import 'monero/french.dart';
import 'monero/german.dart';
import 'monero/italian.dart';
import 'monero/japanese.dart';
import 'monero/portuguese.dart';
import 'monero/russian.dart';
import 'monero/spanish.dart';

List<String> getMoneroWordList(String language) {
  switch (language.toLowerCase()) {
    case 'english':
      return monero.EnglishMnemonics.words;
    case 'chinese (simplified)':
      return ChineseSimplifiedMnemonics.words;
    case 'dutch':
      return DutchMnemonics.words;
    case 'german':
      return GermanMnemonics.words;
    case 'japanese':
      return JapaneseMnemonics.words;
    case 'portuguese':
      return PortugueseMnemonics.words;
    case 'russian':
      return RussianMnemonics.words;
    case 'spanish':
      return SpanishMnemonics.words;
    case 'french':
      return FrenchMnemonics.words;
    case 'italian':
      return ItalianMnemonics.words;
    default:
      return monero.EnglishMnemonics.words;
  }
}
