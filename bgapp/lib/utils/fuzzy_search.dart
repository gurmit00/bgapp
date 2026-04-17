/// Fuzzy search utility — word-aware Levenshtein matching.
///
/// Behaves like Elasticsearch's "fuzziness: AUTO":
///   • 1–3 char words → exact only
///   • 4–5 char words → 1 edit allowed
///   • 6–8 char words → 2 edits allowed
///   • 9+ char words  → 3 edits allowed

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Use a single rolling row to keep memory O(n)
  var prev = List<int>.generate(b.length + 1, (j) => j);
  final curr = List<int>.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (int j = 1; j <= b.length; j++) {
      if (a[i - 1] == b[j - 1]) {
        curr[j] = prev[j - 1];
      } else {
        final sub = prev[j - 1];
        final del = prev[j];
        final ins = curr[j - 1];
        curr[j] = 1 + (sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins));
      }
    }
    // Swap rows
    for (int j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

int _maxEdits(int wordLen) {
  if (wordLen <= 3) return 0;
  if (wordLen <= 5) return 1;
  if (wordLen <= 8) return 2;
  return 3;
}

/// Returns true if [queryWord] fuzzy-matches anywhere in [haystack].
/// Checks:
///   1. Exact substring (fast path)
///   2. Prefix of any word in haystack
///   3. Levenshtein distance ≤ AUTO threshold against each haystack word
bool fuzzyWordMatch(String queryWord, String haystack) {
  if (haystack.contains(queryWord)) return true;

  final maxDist = _maxEdits(queryWord.length);
  final haystackWords = haystack.split(RegExp(r'[\s\-_/.,()]+'));

  for (final hw in haystackWords) {
    if (hw.isEmpty) continue;
    if (hw.startsWith(queryWord)) return true;
    if (maxDist > 0 && _levenshtein(queryWord, hw) <= maxDist) return true;
  }
  return false;
}

/// Returns true if every word in [query] fuzzy-matches [haystack].
/// e.g. fuzzyMatch("turmric 200", "Turmeric Powder 200gm") == true
bool fuzzyMatch(String query, String haystack) {
  final h = haystack.toLowerCase();
  final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
  return words.every((w) => w.isEmpty || fuzzyWordMatch(w, h));
}

/// Exact substring match — every word must appear literally in [haystack].
/// Used when the query ends with a space (user has confirmed the word).
bool exactMatch(String query, String haystack) {
  final h = haystack.toLowerCase();
  final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
  return words.every((w) => w.isEmpty || h.contains(w));
}

/// Auto-selects fuzzy or exact based on whether [rawQuery] ends with a space.
/// Trailing space = "I'm done typing this word, be strict".
bool smartMatch(String rawQuery, String haystack) {
  if (rawQuery.isEmpty) return true;
  return rawQuery.endsWith(' ')
      ? exactMatch(rawQuery, haystack)
      : fuzzyMatch(rawQuery, haystack);
}
