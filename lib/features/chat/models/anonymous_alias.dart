/// Generates a stable, friendly pseudonym (e.g. "Calm Owl") from a user id.
///
/// Students are shown to counselors only by this alias, so their real name
/// never leaves the booking/chat flow. The same id always maps to the same
/// alias, which lets a counselor recognise a returning student without
/// knowing who they are.
class AnonymousAlias {
  AnonymousAlias._();

  static const _adjectives = [
    'Calm',
    'Brave',
    'Gentle',
    'Bright',
    'Quiet',
    'Kind',
    'Hopeful',
    'Steady',
    'Curious',
    'Sunny',
    'Mellow',
    'Clever',
  ];

  static const _animals = [
    'Owl',
    'Panda',
    'Dolphin',
    'Fox',
    'Koala',
    'Otter',
    'Robin',
    'Turtle',
    'Deer',
    'Falcon',
    'Lynx',
    'Heron',
  ];

  static String forUser(String userId) {
    // A simple deterministic hash; String.hashCode is not guaranteed to be
    // stable across runs or platforms.
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final adjective = _adjectives[hash % _adjectives.length];
    final animal = _animals[(hash ~/ _adjectives.length) % _animals.length];
    return '$adjective $animal';
  }
}
