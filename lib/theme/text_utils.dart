// lib/theme/text_utils.dart
String norm(String s) {
  var t = s.trim().toLowerCase();
  const diacritics = [
    '\u0610','\u0611','\u0612','\u0613','\u0614','\u0615','\u0616','\u0617','\u0618','\u0619','\u061A',
    '\u064B','\u064C','\u064D','\u064E','\u064F','\u0650','\u0651','\u0652','\u0653','\u0654','\u0655',
    '\u0656','\u0657','\u0658','\u0659','\u065A','\u065B','\u065C','\u065D','\u065E','\u065F','\u0670'
  ];
  for (final d in diacritics) t = t.replaceAll(d, '');
  t = t
      .replaceAll('ـ', '')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('‏', '')
      .replaceAll('ٔ', '')
      .replaceAll('ٕ', '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}
