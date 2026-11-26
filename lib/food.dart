import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:worms_arena/main.dart';

enum FoodEffectType {
  normal,
  magnet,
  boost,
}

class FoodItem extends PositionComponent with HasGameReference<WormsArenaGame> {
  final int growthValue;
  final Color color;
  final double radius;
  final FoodEffectType effectType;
  final String emoji;
  final bool respawnOnEat;
  double _pulsePhase = 0;
  int _gridKey = 0;
  late final Paragraph _cachedParagraph;

  FoodItem({
    required Vector2 position,
    required this.growthValue,
    required this.color,
    required this.radius,
    this.effectType = FoodEffectType.normal,
    this.emoji = '🍎',
    this.respawnOnEat = false,
  }) : super(position: position, anchor: Anchor.center) {
    final fontSize = radius * 1.55;
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(TextStyle(fontSize: fontSize))
      ..addText(emoji);

    _cachedParagraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: radius * 2.4));
  }

  @override
  void onMount() {
    super.onMount();
    _gridKey = game.foodSpawner.registerFoodInGrid(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 5;
    if (isMounted) {
      _gridKey = game.foodSpawner.updateFoodInGrid(this, _gridKey);
    }
  }

  @override
  void render(Canvas canvas) {
    final pulseScale = 1.0 + (sin(_pulsePhase) * 0.12);
    canvas.save();
    canvas.scale(pulseScale);
    canvas.drawParagraph(
      _cachedParagraph,
      Offset(-_cachedParagraph.width / 2, -_cachedParagraph.height / 2),
    );
    canvas.restore();
  }

  @override
  void onRemove() {
    if (isMounted) {
      game.foodSpawner.unregisterFoodFromGrid(this, _gridKey);
      if (respawnOnEat) {
        game.foodSpawner.scheduleRespawn(
          position: position.clone(),
          growthValue: growthValue,
          color: color,
          radius: radius,
          effectType: effectType,
          emoji: emoji,
        );
      }
    }
    super.onRemove();
  }
}

class _PendingRespawn {
  final Vector2 position;
  final int growthValue;
  final Color color;
  final double radius;
  final FoodEffectType effectType;
  final String emoji;
  double remainingSeconds;

  _PendingRespawn({
    required this.position,
    required this.growthValue,
    required this.color,
    required this.radius,
    required this.effectType,
    required this.emoji,
    required this.remainingSeconds,
  });
}

class FoodSpawner extends Component with HasGameReference<WormsArenaGame> {
  static const double gridCellSize = 300.0;

  final Random _random = Random();
  final int targetFoodCount;
  final List<_PendingRespawn> _pendingRespawns = [];
  final Map<int, List<FoodItem>> _gridBuckets = {};
  int _activeFoodCount = 0;
  double _spawnCheckTimer = 0;

  static const List<String> _foodEmojis = [
    '🍅',
    '🫒',
    '🥭',
    '🍎',
    '🍓',
    '🍍',
    '🍋‍🟩',
    '🍉',
    '🍌',
    '🫐',
    '🍔',
    '🍕',
    '🍗',
    '🌭',
  ];

  FoodSpawner({this.targetFoodCount = 420});

  int _cellCoord(double v) => (v / gridCellSize).floor();

  int _packCellKey(int cx, int cy) => (cx * 73856093) ^ (cy * 19349663);

  int _keyForPosition(Vector2 pos) {
    return _packCellKey(_cellCoord(pos.x), _cellCoord(pos.y));
  }

  int registerFoodInGrid(FoodItem food) {
    final key = _keyForPosition(food.position);
    final list = _gridBuckets.putIfAbsent(key, () => <FoodItem>[]);
    if (!list.contains(food)) {
      list.add(food);
      _activeFoodCount++;
    }
    return key;
  }

  int updateFoodInGrid(FoodItem food, int oldKey) {
    final newKey = _keyForPosition(food.position);
    if (newKey == oldKey) return oldKey;
    final oldList = _gridBuckets[oldKey];
    if (oldList != null) {
      oldList.remove(food);
      if (oldList.isEmpty) {
        _gridBuckets.remove(oldKey);
      }
    }
    final newList = _gridBuckets.putIfAbsent(newKey, () => <FoodItem>[]);
    if (!newList.contains(food)) {
      newList.add(food);
    }
    return newKey;
  }

  void unregisterFoodFromGrid(FoodItem food, int key) {
    final list = _gridBuckets[key];
    if (list != null && list.remove(food)) {
      if (_activeFoodCount > 0) _activeFoodCount--;
      if (list.isEmpty) {
        _gridBuckets.remove(key);
      }
    }
  }

  Iterable<FoodItem> getFoodsNear(Vector2 center, double radius) sync* {
    final minCx = _cellCoord(center.x - radius);
    final maxCx = _cellCoord(center.x + radius);
    final minCy = _cellCoord(center.y - radius);
    final maxCy = _cellCoord(center.y + radius);

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final list = _gridBuckets[_packCellKey(cx, cy)];
        if (list == null) continue;
        for (int i = 0; i < list.length; i++) {
          final food = list[i];
          if (!food.isRemoved) {
            yield food;
          }
        }
      }
    }
  }

  void scheduleRespawn({
    required Vector2 position,
    required int growthValue,
    required Color color,
    required double radius,
    required FoodEffectType effectType,
    required String emoji,
  }) {
    _pendingRespawns.add(
      _PendingRespawn(
        position: position,
        growthValue: growthValue,
        color: color,
        radius: radius,
        effectType: effectType,
        emoji: emoji,
        remainingSeconds: 30.0,
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final initialBatch = min(targetFoodCount, 1200);
    for (int i = 0; i < initialBatch; i++) {
      spawnOneFood(respawnOnEat: true);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (int i = _pendingRespawns.length - 1; i >= 0; i--) {
      final item = _pendingRespawns[i];
      item.remainingSeconds -= dt;
      if (item.remainingSeconds <= 0) {
        _pendingRespawns.removeAt(i);
        game.world.add(
          FoodItem(
            position: item.position,
            growthValue: item.growthValue,
            color: item.color,
            radius: item.radius,
            effectType: item.effectType,
            emoji: item.emoji,
            respawnOnEat: true,
          ),
        );
      }
    }

    _spawnCheckTimer += dt;
    if (_spawnCheckTimer < 0.1) return;
    _spawnCheckTimer = 0;

    final desiredExtra = max(0, targetFoodCount - _pendingRespawns.length);
    if (_activeFoodCount < desiredExtra) {
      final missing = min(150, desiredExtra - _activeFoodCount);
      for (int i = 0; i < missing; i++) {
        spawnOneFood(respawnOnEat: true);
      }
    }
  }

  void spawnOneFood({
    Vector2? exactPosition,
    int? customGrowth,
    Color? customColor,
    FoodEffectType? customEffect,
    bool respawnOnEat = false,
  }) {
    final pos = exactPosition ?? _randomArenaPoint();
    final isBig = _random.nextDouble() < 0.22;
    final growth = customGrowth ?? (isBig ? 2 : 1);
    final rad = customColor != null
        ? 9.5
        : (customEffect != null && customEffect != FoodEffectType.normal
            ? 10.5
            : (isBig ? 8.5 : 6.0));

    const palette = [
      Color(0xFFFFBE0B),
      Color(0xFFFB5607),
      Color(0xFFFF006E),
      Color(0xFF8338EC),
      Color(0xFF06D6A0),
    ];

    FoodEffectType effect = customEffect ?? FoodEffectType.normal;
    Color chosenColor;
    String chosenEmoji;

    if (customColor != null) {
      chosenColor = customColor;
      chosenEmoji = _foodEmojis[_random.nextInt(_foodEmojis.length)];
    } else if (customEffect == null) {
      final roll = _random.nextDouble();
      if (roll < 0.08) {
        effect = FoodEffectType.magnet;
        chosenColor = const Color(0xFF00BBF9);
        chosenEmoji = '🧲';
      } else if (roll < 0.16) {
        effect = FoodEffectType.boost;
        chosenColor = const Color(0xFFFF006E);
        chosenEmoji = '⚡';
      } else {
        effect = FoodEffectType.normal;
        chosenColor = palette[_random.nextInt(palette.length)];
        chosenEmoji = _foodEmojis[_random.nextInt(_foodEmojis.length)];
      }
    } else {
      if (effect == FoodEffectType.magnet) {
        chosenColor = const Color(0xFF00BBF9);
        chosenEmoji = '🧲';
      } else if (effect == FoodEffectType.boost) {
        chosenColor = const Color(0xFFFF006E);
        chosenEmoji = '⚡';
      } else {
        chosenColor = palette[_random.nextInt(palette.length)];
        chosenEmoji = _foodEmojis[_random.nextInt(_foodEmojis.length)];
      }
    }

    game.world.add(
      FoodItem(
        position: pos,
        growthValue: growth,
        color: chosenColor,
        radius: rad,
        effectType: effect,
        emoji: chosenEmoji,
        respawnOnEat: respawnOnEat,
      ),
    );
  }

  Vector2 _randomArenaPoint() {
    final limit = WormsArenaGame.arenaRadius - WormsArenaGame.zoneEdgeInset - 60;
    final x = (_random.nextDouble() * 2 - 1) * limit;
    final y = (_random.nextDouble() * 2 - 1) * limit;
    return Vector2(x, y);
  }
}
