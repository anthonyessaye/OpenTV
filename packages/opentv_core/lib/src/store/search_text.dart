/// Normalises a title into the form stored in the indexed `searchName`
/// columns, and the form a query is normalised into before matching.
///
/// Write and read must use this same function or the index is useless, which
/// is why it lives on its own rather than inside either path.
///
/// Deliberately conservative: lower case, fold diacritics, reduce punctuation
/// to spaces, collapse runs of whitespace. It does not strip quality suffixes
/// or the `UK|` style country prefixes providers attach, because users search
/// for those too.
String normaliseForSearch(String raw) {
  final buffer = StringBuffer();
  var lastWasSpace = true; // suppresses a leading space

  for (final rune in raw.toLowerCase().runes) {
    final folded = _fold(rune);
    if (folded == null) {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
      continue;
    }
    buffer.write(folded);
    lastWasSpace = false;
  }

  final result = buffer.toString();
  return lastWasSpace && result.isNotEmpty
      ? result.substring(0, result.length - 1)
      : result;
}

/// Returns the folded character, or null if the rune is not word content.
String? _fold(int rune) {
  // Digits and unaccented lower-case letters pass through.
  if ((rune >= 0x30 && rune <= 0x39) || (rune >= 0x61 && rune <= 0x7A)) {
    return String.fromCharCode(rune);
  }

  final mapped = _diacritics[rune];
  if (mapped != null) return mapped;

  // Anything else — punctuation, symbols, separators — becomes a break.
  return null;
}

/// Latin-1 Supplement and Latin Extended-A folded to ASCII.
///
/// Channel names arrive in many languages and a viewer typing "telefe" should
/// find "Telefé".
const Map<int, String> _diacritics = {
  0xE0: 'a',
  0xE1: 'a',
  0xE2: 'a',
  0xE3: 'a',
  0xE4: 'a',
  0xE5: 'a',
  0xE6: 'ae',
  0xE7: 'c',
  0xE8: 'e',
  0xE9: 'e',
  0xEA: 'e',
  0xEB: 'e',
  0xEC: 'i',
  0xED: 'i',
  0xEE: 'i',
  0xEF: 'i',
  0xF0: 'd',
  0xF1: 'n',
  0xF2: 'o',
  0xF3: 'o',
  0xF4: 'o',
  0xF5: 'o',
  0xF6: 'o',
  0xF8: 'o',
  0xF9: 'u',
  0xFA: 'u',
  0xFB: 'u',
  0xFC: 'u',
  0xFD: 'y',
  0xFF: 'y',
  0xFE: 'th',
  0xDF: 'ss',
  0x101: 'a',
  0x103: 'a',
  0x105: 'a',
  0x107: 'c',
  0x109: 'c',
  0x10B: 'c',
  0x10D: 'c',
  0x10F: 'd',
  0x111: 'd',
  0x113: 'e',
  0x115: 'e',
  0x117: 'e',
  0x119: 'e',
  0x11B: 'e',
  0x11D: 'g',
  0x11F: 'g',
  0x121: 'g',
  0x123: 'g',
  0x125: 'h',
  0x127: 'h',
  0x129: 'i',
  0x12B: 'i',
  0x12D: 'i',
  0x12F: 'i',
  0x131: 'i',
  0x135: 'j',
  0x137: 'k',
  0x13A: 'l',
  0x13C: 'l',
  0x13E: 'l',
  0x140: 'l',
  0x142: 'l',
  0x144: 'n',
  0x146: 'n',
  0x148: 'n',
  0x14D: 'o',
  0x14F: 'o',
  0x151: 'o',
  0x153: 'oe',
  0x155: 'r',
  0x157: 'r',
  0x159: 'r',
  0x15B: 's',
  0x15D: 's',
  0x15F: 's',
  0x161: 's',
  0x163: 't',
  0x165: 't',
  0x167: 't',
  0x169: 'u',
  0x16B: 'u',
  0x16D: 'u',
  0x16F: 'u',
  0x171: 'u',
  0x173: 'u',
  0x175: 'w',
  0x177: 'y',
  0x17A: 'z',
  0x17C: 'z',
  0x17E: 'z',
};
