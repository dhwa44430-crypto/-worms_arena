import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:worms_arena/food.dart';
import 'package:worms_arena/main.dart';

class BotWorm extends PositionComponent with HasGameReference<WormsArenaGame> {
  final Random _random = Random();
  @override
  double angle;
  int segmentCount;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Vector2> pathHistory = [];
  double _aiTimer = 0;
  double _targetAngle;
  bool _isDead = false;
  double _magnetTimer = 0;
  double _boostTimer = 0;
  List<Vector2> _cachedSegments = [];
  int _cachedSegmentCount = -1;
  Vector2? _lastSampledHeadPos;

  BotWorm({
    required Vector2 startPosition,
    required this.angle,
    required this.segmentCount,
    required this.primaryColor,
    required this.secondaryColor,
  })  : _targetAngle = angle,
        super(position: startPosition, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < 400; i++) {
      pathHistory.add(position.clone());
    }
    _cachedSegments = _computeSegmentPositions();
    _cachedSegmentCount = segmentCount;
    _lastSampledHeadPos = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead) return;

    if (_magnetTimer > 0) {
      _magnetTimer = max(0.0, _magnetTimer - dt);
    }
    if (_boostTimer > 0) {
      _boostTimer = max(0.0, _boostTimer - dt);
    }

    _updateAiDirection(dt);

    final diff = _normalizeAngle(_targetAngle - angle);
    const maxTurnSpeed = 4.2;
    angle += diff.clamp(-maxTurnSpeed * dt, maxTurnSpeed * dt);
    angle = _normalizeAngle(angle);

    final botSpeed = _boostTimer > 0 ? 275.0 : 165.0;
    position += Vector2(cos(angle), sin(angle)) * botSpeed * dt;

    // إذا خرج البوت عن حدود الساحة يموت ويتحول إلى طعام
    if (position.length >= WormsArenaGame.arenaRadius - 12) {
      dieAndDropFood();
      return;
    }

    if (_magnetTimer > 0) {
      _pullNearbyFood(dt);
    }

    _checkEatingFood();
    _checkCollisions();

    pathHistory.insert(0, position.clone());
    final maxPoints =
        (segmentCount * WormsArenaGame.baseSegmentSpacing / 2).ceil() + 60;
    if (pathHistory.length > maxPoints) {
      pathHistory.removeRange(maxPoints, pathHistory.length);
    }

    _cachedSegments = _computeSegmentPositions();
    _cachedSegmentCount = segmentCount;
    _lastSampledHeadPos = position.clone();
  }

  void _pullNearbyFood(double dt) {
    const magnetRadius = 220.0;
    const magnetRadiusSq = magnetRadius * magnetRadius;
    const pullSpeed = 340.0;
    final bx = position.x;
    final by = position.y;

    for (final food in game.foodSpawner.getFoodsNear(position, magnetRadius)) {
      if (food.isRemoved) continue;
      final dx = bx - food.position.x;
      final dy = by - food.position.y;
      final distSq = dx * dx + dy * dy;
      if (distSq > 0 && distSq <= magnetRadiusSq) {
        final dist = sqrt(distSq);
        final step = min(dist, pullSpeed * dt);
        food.position.x += (dx / dist) * step;
        food.position.y += (dy / dist) * step;
      }
    }
  }

  void _updateAiDirection(double dt) {
    _aiTimer -= dt;

    // تفادي حافة الساحة فوراً
    if (position.length > WormsArenaGame.arenaRadius - 220) {
      final toCenter = -position;
      _targetAngle = atan2(toCenter.y, toCenter.x);
      return;
    }

    if (_aiTimer <= 0) {
      _aiTimer = 0.35 + _random.nextDouble() * 0.45;

      // البحث عن أقرب طعام ضمن مدى معقول
      FoodItem? nearestFood;
      const maxSearchDist = 360.0;
      double bestDistSq = maxSearchDist * maxSearchDist;
      final bx = position.x;
      final by = position.y;

      for (final food in game.foodSpawner.getFoodsNear(position, maxSearchDist)) {
        if (food.isRemoved) continue;
        final dx = food.position.x - bx;
        final dy = food.position.y - by;
        final dSq = dx * dx + dy * dy;
        if (dSq < bestDistSq) {
          bestDistSq = dSq;
          nearestFood = food;
        }
      }

      if (nearestFood != null) {
        final dir = nearestFood.position - position;
        _targetAngle = atan2(dir.y, dir.x);
      } else {
        _targetAngle += (_random.nextDouble() - 0.5) * 2.2;
      }
    }
  }

  void _checkEatingFood() {
    const eatRadius = 22.0;
    final bx = position.x;
    final by = position.y;

    for (final food in game.foodSpawner.getFoodsNear(position, eatRadius + 16.0)) {
      if (food.isRemoved) continue;
      final reach = eatRadius + food.radius;
      final dx = bx - food.position.x;
      final dy = by - food.position.y;
      if (dx * dx + dy * dy <= reach * reach) {
        if (food.effectType == FoodEffectType.magnet) {
          _magnetTimer = 6.0;
        } else if (food.effectType == FoodEffectType.boost) {
          _boostTimer = 4.0;
        }
        game.foodSpawner.markDepletedSpot(food.position.clone());
        food.removeFromParent();
        segmentCount += food.growthValue;
      }
    }
  }

  void _checkCollisions() {
    const hitRadius = 15.0;
    const minDist = hitRadius + 10;
    const minDistSq = minDist * minDist;
    final bx = position.x;
    final by = position.y;

    // 1. اصطدام رأس البوت بجسم اللاعب
    final playerSegments = game.worm.currentSegmentPositions;
    for (int i = 1; i < playerSegments.length; i++) {
      final seg = playerSegments[i];
      final dx = bx - seg.x;
      final dy = by - seg.y;
      if (dx * dx + dy * dy < minDistSq) {
        dieAndDropFood();
        return;
      }
    }

    // 2. اصطدام رأس البوت بجسم بوت آخر
    for (final child in game.world.children) {
      if (child is! BotWorm || child == this || child._isDead) continue;
      final otherSegments = child.sampleSegmentPositions();
      for (int i = 1; i < otherSegments.length; i++) {
        final seg = otherSegments[i];
        final dx = bx - seg.x;
        final dy = by - seg.y;
        if (dx * dx + dy * dy < minDistSq) {
          dieAndDropFood();
          return;
        }
      }
    }
  }

  void dieAndDropFood() {
    if (_isDead) return;
    _isDead = true;

    final segments = sampleSegmentPositions();
    for (int i = 0; i < segments.length; i += 2) {
      game.foodSpawner.spawnOneFood(
        exactPosition: segments[i],
        customGrowth: 2,
        customColor: i % 4 == 0 ? primaryColor : secondaryColor,
      );
    }

    removeFromParent();
  }

  double _normalizeAngle(double a) {
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a < -pi) {
      a += 2 * pi;
    }
    return a;
  }

  @override
  void render(Canvas canvas) {
    final segments = sampleSegmentPositions();

    for (int i = segments.length - 1; i >= 0; i--) {
      final pos = segments[i];
      final localPos = Offset(pos.x - position.x, pos.y - position.y);
      final isHead = i == 0;
      final radius = isHead ? 15.0 : max(7.5, 13.5 - (i * 0.05));

      final paint = Paint()
        ..color = isHead
            ? primaryColor
            : (i % 2 == 0 ? primaryColor : secondaryColor);

      canvas.drawCircle(localPos, radius, paint);

      if (isHead) {
        final eyeOffset = Offset(cos(angle) * 5.5, sin(angle) * 5.5);
        final eyePaint = Paint()..color = const Color(0xFF0B0F19);
        canvas.drawCircle(localPos + eyeOffset, 3.0, eyePaint);
      }
    }
  }

  List<Vector2> sampleSegmentPositions() {
    if (_cachedSegments.isNotEmpty &&
        _cachedSegmentCount == segmentCount &&
        _lastSampledHeadPos != null &&
        _lastSampledHeadPos == position) {
      return _cachedSegments;
    }
    _cachedSegments = _computeSegmentPositions();
    _cachedSegmentCount = segmentCount;
    _lastSampledHeadPos = position.clone();
    return _cachedSegments;
  }

  List<Vector2> _computeSegmentPositions() {
    final result = <Vector2>[position.clone()];
    if (pathHistory.isEmpty) return result;

    int currentIndex = 0;
    double accumulatedDist = 0;

    for (int seg = 1; seg < segmentCount; seg++) {
      final targetDist = seg * WormsArenaGame.baseSegmentSpacing;
      while (currentIndex < pathHistory.length - 1) {
        final p1 = pathHistory[currentIndex];
        final p2 = pathHistory[currentIndex + 1];
        final stepDist = p1.distanceTo(p2);

        if (accumulatedDist + stepDist >= targetDist) {
          final remain = targetDist - accumulatedDist;
          final t = stepDist == 0 ? 0.0 : (remain / stepDist).clamp(0.0, 1.0);
          result.add(p1 + (p2 - p1) * t);
          break;
        }
        accumulatedDist += stepDist;
        currentIndex++;
      }
      if (result.length <= seg) {
        result.add(pathHistory.last.clone());
      }
    }

    return result;
  }
}

class BotSpawner extends Component with HasGameReference<WormsArenaGame> {
  final Random _random = Random();
  final int targetBotCount;
  double _respawnTimer = 0;
  int _activeBotCount = 0;

  static const List<List<Color>> _skinPairs = [
    [Color(0xFFFF595E), Color(0xFFFF924C)],
    [Color(0xFF8AC926), Color(0xFF52B788)],
    [Color(0xFFFFCA3A), Color(0xFFF77F00)],
    [Color(0xFFC77DFF), Color(0xFF7209B7)],
    [Color(0xFFF72585), Color(0xFFB5179E)],
  ];

  BotSpawner({this.targetBotCount = 10});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < targetBotCount; i++) {
      _spawnBot();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _respawnTimer += dt;
    if (_respawnTimer >= 1.5) {
      _respawnTimer = 0;
      if (_activeBotCount < targetBotCount) {
        _spawnBot();
      }
    }
  }

  void _spawnBot() {
    final r = 220 + _random.nextDouble() * (WormsArenaGame.arenaRadius - 350);
    final theta = _random.nextDouble() * 2 * pi;
    final pos = Vector2(cos(theta) * r, sin(theta) * r);
    final pair = _skinPairs[_random.nextInt(_skinPairs.length)];

    final bot = BotWorm(
      startPosition: pos,
      angle: _random.nextDouble() * 2 * pi,
      segmentCount: 10 + _random.nextInt(14),
      primaryColor: pair[0],
      secondaryColor: pair[1],
    );
    _activeBotCount++;
    bot.removed.then((_) {
      if (_activeBotCount > 0) _activeBotCount--;
    });
    game.world.add(bot);
  }
}
