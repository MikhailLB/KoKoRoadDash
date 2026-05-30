/// A cosmetic chicken variant. `id` maps directly to the asset filenames
/// (`chicken_<id>_asset.webp` / `chicken_<id>_smash_asset.webp`).
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.cost,
    this.tagline = '',
  });

  final String id;
  final String name;

  /// Coins required to unlock. 0 means free / unlocked by default.
  final int cost;
  final String tagline;

  bool get isFree => cost == 0;

  static const List<Skin> catalog = <Skin>[
    Skin(id: 'default', name: 'Koko', cost: 0, tagline: 'The original rooster'),
    Skin(id: 'gold', name: 'Golden', cost: 250, tagline: 'Worth a fortune'),
    Skin(id: 'samurai', name: 'Samurai', cost: 400, tagline: 'Disciplined dasher'),
    Skin(id: 'pharaon', name: 'Pharaoh', cost: 600, tagline: 'Ancient roadster'),
    Skin(id: 'dragon', name: 'Dragon', cost: 900, tagline: 'Breathes fire'),
  ];

  static Skin byId(String id) =>
      catalog.firstWhere((Skin s) => s.id == id, orElse: () => catalog.first);
}
