import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:worms_arena/main.dart';

enum FoodEffectType {
  normal,
  magnet,
  boost,
}

class FoodItem {
  final Vector2 position;
  final int growthValue;
  final Color color;
  final double radius;
  final FoodEffectType effectType;
  final String emoji;
  final bool respawnOnEat;
  double? remainingLifeSeconds;
  double pulsePhase = 0;
  int gridKey = 0;
  double lastGridX;
  double lastGridY;
  bool isRemoved = false;
  late final Paragraph cachedParagraph;

  FoodItem({
    required this.position,
    required this.growthValue,
    required this.color,
    required this.radius,
    this.effectType = FoodEffectType.normal,
    this.emoji = '🍎',
    this.respawnOnEat = false,
    this.remainingLifeSeconds,
  })  : lastGridX = position.x,
        lastGridY = position.y {
    final fontSize = radius * 1.55;
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
      ),
    )
      ..pushStyle(TextStyle(fontSize: fontSize))
      ..addText(emoji);

    cachedParagraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: radius * 2.4));
  }

  void removeFromParent() {
    isRemoved = true;
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
  final List<FoodItem> _allFoods = [];
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
        remainingSeconds: 8.0,
      ),
    );
  }

  void _addFoodItem(FoodItem food) {
    _allFoods.add(food);
    food.gridKey = registerFoodInGrid(food);
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
        _addFoodItem(
          FoodItem(
            position: _emptyOrSparseArenaPoint(),
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

    for (int i = _allFoods.length - 1; i >= 0; i--) {
      final food = _allFoods[i];
      if (!food.isRemoved && food.remainingLifeSeconds != null) {
        food.remainingLifeSeconds = food.remainingLifeSeconds! - dt;
        if (food.remainingLifeSeconds! <= 0) {
          food.isRemoved = true;
        }
      }

      if (food.isRemoved) {
        unregisterFoodFromGrid(food, food.gridKey);
        if (food.respawnOnEat) {
          scheduleRespawn(
            position: _emptyOrSparseArenaPoint(),
            growthValue: food.growthValue,
            color: food.color,
            radius: food.radius,
            effectType: food.effectType,
            emoji: food.emoji,
          );
        }
        _allFoods.removeAt(i);
        continue;
      }

      if ((food.position.x - food.lastGridX).abs() >= 1.0 ||
          (food.position.y - food.lastGridY).abs() >= 1.0) {
        food.lastGridX = food.position.x;
        food.lastGridY = food.position.y;
        food.gridKey = updateFoodInGrid(food, food.gridKey);
      }

      final dx = food.position.x - game.worm.head.position.x;
      final dy = food.position.y - game.worm.head.position.y;
      if (dx.abs() <= 900 && dy.abs() <= 650) {
        food.pulsePhase += dt * 5;
      }
    }

    _spawnCheckTimer += dt;
    if (_spawnCheckTimer < 0.05) return;
    _spawnCheckTimer = 0;

    final desiredExtra = max(0, targetFoodCount - _pendingRespawns.length);
    if (_activeFoodCount < desiredExtra) {
      final missing = min(400, desiredExtra - _activeFoodCount);
      for (int i = 0; i < missing; i++) {
        spawnOneFood(
          exactPosition: _emptyOrSparseArenaPoint(),
          respawnOnEat: true,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final viewCenter = game.camera.viewfinder.position;
    final halfW = game.size.x * 0.65;
    final halfH = game.size.y * 0.65;

    final minCx = _cellCoord(viewCenter.x - halfW);
    final maxCx = _cellCoord(viewCenter.x + halfW);
    final minCy = _cellCoord(viewCenter.y - halfH);
    final maxCy = _cellCoord(viewCenter.y + halfH);

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final list = _gridBuckets[_packCellKey(cx, cy)];
        if (list == null) continue;
        for (int i = 0; i < list.length; i++) {
          final food = list[i];
          if (food.isRemoved) continue;

          final pulseScale = 1.0 + (sin(food.pulsePhase) * 0.12);
          canvas.save();
          canvas.translate(food.position.x, food.position.y);
          canvas.scale(pulseScale);
          canvas.drawParagraph(
            food.cachedParagraph,
            Offset(
              -food.cachedParagraph.width / 2,
              -food.cachedParagraph.height / 2,
            ),
          );
          canvas.restore();
        }
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
      if (roll < 0.015) {
        effect = FoodEffectType.magnet;
        chosenColor = const Color(0xFF00BBF9);
        chosenEmoji = '🧲';
      } else if (roll < 0.03) {
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

    _addFoodItem(
      FoodItem(
        position: pos,
        growthValue: growth,
        color: chosenColor,
        radius: rad,
        effectType: effect,
        emoji: chosenEmoji,
        respawnOnEat: respawnOnEat,
        remainingLifeSeconds: exactPosition != null ? 8.0 : null,
      ),
    );
  }

  Vector2 _emptyOrSparseArenaPoint() {
    Vector2? bestCandidate;
    int lowestCount = 1 << 30;
    for (int i = 0; i < 2; i++) {
      final candidate = _randomArenaPoint();
      final count = _gridBuckets[_keyForPosition(candidate)]?.length ?? 0;
      if (count == 0) {
        return candidate;
      }
      if (count < lowestCount) {
        lowestCount = count;
        bestCandidate = candidate;
      }
    }
    return bestCandidate ?? _randomArenaPoint();
  }

  Vector2 _randomArenaPoint() {
    final limit = WormsArenaGame.arenaRadius - WormsArenaGame.zoneEdgeInset - 60;
    final x = (_random.nextDouble() * 2 - 1) * limit;
    final y = (_random.nextDouble() * 2 - 1) * limit;
    return Vector2(x, y);
  }
}
