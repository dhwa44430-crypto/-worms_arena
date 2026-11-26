import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worms_arena/bots.dart';
import 'package:worms_arena/food.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WormsArenaScreen(),
    ),
  );
}

class WormsArenaScreen extends StatefulWidget {
  const WormsArenaScreen({super.key});

  @override
  State<WormsArenaScreen> createState() => _WormsArenaScreenState();
}

class _WormsArenaScreenState extends State<WormsArenaScreen> {
  late final WormsArenaGame _game;

  @override
  void initState() {
    super.initState();
    _game = WormsArenaGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101522),
      body: Stack(
        children: [
          GameWidget<WormsArenaGame>(game: _game),

          // شريط النقاط والطول في الأعلى
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _game.scoreNotifier,
                    builder: (_, score, __) => _StatBadge(
                      label: 'النقاط',
                      value: '$score',
                      color: const Color(0xFFFFBE0B),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _game.lengthNotifier,
                    builder: (_, length, __) => _StatBadge(
                      label: 'الطول',
                      value: '$length',
                      color: const Color(0xFF00F5D4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // زر السرعة (Boost) أسفل اليمين
          Positioned(
            right: 20,
            bottom: 28,
            child: GestureDetector(
              onTapDown: (_) => _game.setBoosting(true),
              onTapUp: (_) => _game.setBoosting(false),
              onTapCancel: () => _game.setBoosting(false),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF006E).withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF006E).withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: Colors.white, size: 28),
                    Text(
                      'سرعة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // نافذة الخسارة وإعادة اللعب
          ValueListenableBuilder<bool>(
            valueListenable: _game.gameOverNotifier,
            builder: (_, isGameOver, __) {
              if (!isGameOver) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withValues(alpha: 0.72),
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2234),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'انتهت الجولة!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<int>(
                        valueListenable: _game.scoreNotifier,
                        builder: (_, score, __) => Text(
                          'نقاطك: $score',
                          style: const TextStyle(
                            color: Color(0xFFFFBE0B),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: _game.lengthNotifier,
                        builder: (_, length, __) => Text(
                          'أقصى طول: $length',
                          style: const TextStyle(
                            color: Color(0xFF00F5D4),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BBF9),
                            foregroundColor: const Color(0xFF0B0F19),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _game.restartGame,
                          child: const Text(
                            'العب مجدداً',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2234).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class WormsArenaGame extends FlameGame with PanDetector {
  static const double arenaRadius = 8400;
  static const double zoneEdgeInset = 90;
  static const double normalSpeed = 195;
  static const double boostSpeed = 320;
  static const double baseSegmentSpacing = 12;

  late final WormPlayer worm;
  late final FoodSpawner foodSpawner;
  late final BotSpawner botSpawner;
  Vector2? targetDirection;
  bool isBoosting = false;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> lengthNotifier = ValueNotifier<int>(12);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier<bool>(false);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.add(ArenaBackground(radius: arenaRadius));

    foodSpawner = FoodSpawner(targetFoodCount: 1600);
    world.add(foodSpawner);

    botSpawner = BotSpawner(targetBotCount: 10);
    world.add(botSpawner);

    worm = WormPlayer(startPosition: Vector2.zero());
    world.add(worm);
    camera.follow(worm.head);

    scoreNotifier.value = 0;
    lengthNotifier.value = worm.segmentCount;
    gameOverNotifier.value = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    final maxCamX = max(0.0, arenaRadius - halfW);
    final maxCamY = max(0.0, arenaRadius - halfH);
    camera.viewfinder.position = Vector2(
      worm.head.position.x.clamp(-maxCamX, maxCamX),
      worm.head.position.y.clamp(-maxCamY, maxCamY),
    );
  }

  void setBoosting(bool active) {
    isBoosting = active && !worm.isDead && worm.segmentCount > 10;
  }

  void restartGame() {
    isBoosting = false;
    for (final bot in world.children.whereType<BotWorm>().toList()) {
      bot.removeFromParent();
    }
    worm.reset(Vector2.zero());
    scoreNotifier.value = 0;
    lengthNotifier.value = worm.segmentCount;
    gameOverNotifier.value = false;
    botSpawner = BotSpawner(targetBotCount: 10);
    world.add(botSpawner);
  }

  @override
  void onPanStart(DragStartInfo info) {
    _updateTargetFromScreen(info.eventPosition.global);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _updateTargetFromScreen(info.eventPosition.global);
  }

  @override
  void onPanEnd(DragEndInfo info) {
    targetDirection = null;
  }

  @override
  void onPanCancel() {
    targetDirection = null;
  }

  void _updateTargetFromScreen(Vector2 screenPos) {
    final center = size / 2;
    final delta = screenPos - center;
    if (delta.length > 8) {
      targetDirection = delta.normalized();
    }
  }
}

class ArenaBackground extends PositionComponent {
  final double radius;
  double _glowPhase = 0;

  ArenaBackground({required this.radius});

  @override
  void update(double dt) {
    super.update(dt);
    _glowPhase += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFF101522);
    canvas.drawRect(
      Rect.fromLTRB(-radius - 300, -radius - 300, radius + 300, radius + 300),
      bgPaint,
    );

    final gridPaint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1;

    const step = 60.0;
    for (double x = -radius; x <= radius; x += step) {
      canvas.drawLine(Offset(x, -radius), Offset(x, radius), gridPaint);
    }
    for (double y = -radius; y <= radius; y += step) {
      canvas.drawLine(Offset(-radius, y), Offset(radius, y), gridPaint);
    }

    final pulse = 0.5 + 0.5 * sin(_glowPhase);
    const liftOffset = 40.0;
    const inset = WormsArenaGame.zoneEdgeInset;
    final zoneRect = Rect.fromLTRB(
      -radius + inset,
      -radius - liftOffset + inset,
      radius - inset,
      radius - liftOffset - inset,
    );

    final outerGlowPaint = Paint()
      ..color = const Color(0xFFFF002B).withValues(alpha: 0.25 + pulse * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22 + pulse * 14
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + pulse * 14);
    canvas.drawRect(zoneRect, outerGlowPaint);

    final borderPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFF1E42),
        const Color(0xFFFF6B6B),
        pulse,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 + pulse * 4;
    canvas.drawRect(zoneRect, borderPaint);
  }
}

class WormHeadAnchor extends PositionComponent {
  WormHeadAnchor({required Vector2 position})
      : super(position: position, anchor: Anchor.center);
}

class WormPlayer extends Component with HasGameReference<WormsArenaGame> {
  final WormHeadAnchor head;
  double angle = 0;
  int segmentCount = 12;
  int score = 0;
  bool isDead = false;
  double _boostDrainTimer = 0;
  double _magnetTimer = 0;
  double _foodBoostTimer = 0;
  final List<Vector2> pathHistory = [];
  List<Vector2> currentSegmentPositions = [];

  WormPlayer({required Vector2 startPosition})
      : head = WormHeadAnchor(position: startPosition);

  void reset(Vector2 startPosition) {
    head.position = startPosition.clone();
    angle = 0;
    segmentCount = 12;
    score = 0;
    isDead = false;
    _boostDrainTimer = 0;
    _magnetTimer = 0;
    _foodBoostTimer = 0;
    pathHistory.clear();
    for (int i = 0; i < 400; i++) {
      pathHistory.add(head.position.clone());
    }
    currentSegmentPositions = _sampleSegmentPositions();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(head);
    reset(head.position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    if (_magnetTimer > 0) {
      _magnetTimer = max(0.0, _magnetTimer - dt);
    }
    if (_foodBoostTimer > 0) {
      _foodBoostTimer = max(0.0, _foodBoostTimer - dt);
    }

    final desiredDir = game.targetDirection;
    if (desiredDir != null && desiredDir.length > 0) {
      final targetAngle = atan2(desiredDir.y, desiredDir.x);
      final diff = _normalizeAngle(targetAngle - angle);
      const maxTurnSpeed = 24.0;
      angle += diff.clamp(-maxTurnSpeed * dt, maxTurnSpeed * dt);
      angle = _normalizeAngle(angle);
    }

    final activeBoost = game.isBoosting && segmentCount > 10;
    if (!activeBoost) {
      game.isBoosting = false;
    }

    final speed = activeBoost
        ? WormsArenaGame.boostSpeed
        : (_foodBoostTimer > 0
            ? WormsArenaGame.boostSpeed
            : WormsArenaGame.normalSpeed);
    final velocity = Vector2(cos(angle), sin(angle)) * speed;
    head.position += velocity * dt;

    if (activeBoost) {
      _boostDrainTimer += dt;
      if (_boostDrainTimer >= 0.35) {
        _boostDrainTimer = 0;
        segmentCount = max(10, segmentCount - 1);
        game.lengthNotifier.value = segmentCount;
      }
    }

    final limit = WormsArenaGame.arenaRadius - WormsArenaGame.zoneEdgeInset - 12;
    if (head.position.x.abs() >= limit ||
        head.position.y.abs() >= limit ||
        _hitAnyBotBody()) {
      _die();
      return;
    }

    if (_magnetTimer > 0) {
      _pullNearbyFood(dt);
    }

    _checkFoodEating();

    pathHistory.insert(0, head.position.clone());
    final maxPoints =
        (segmentCount * WormsArenaGame.baseSegmentSpacing / 2).ceil() + 60;
    if (pathHistory.length > maxPoints) {
      pathHistory.removeRange(maxPoints, pathHistory.length);
    }

    currentSegmentPositions = _sampleSegmentPositions();
  }

  void _pullNearbyFood(double dt) {
    const magnetRadius = 230.0;
    const pullSpeed = 350.0;
    for (final food in game.world.children.whereType<FoodItem>()) {
      if (food.isRemoved) continue;
      final toHead = head.position - food.position;
      final dist = toHead.length;
      if (dist > 0 && dist <= magnetRadius) {
        final step = min(dist, pullSpeed * dt);
        food.position += (toHead / dist) * step;
      }
    }
  }

  bool _hitAnyBotBody() {
    for (final bot in game.world.children.whereType<BotWorm>()) {
      final botSegments = bot.sampleSegmentPositions();
      for (int i = 1; i < botSegments.length; i++) {
        if (head.position.distanceTo(botSegments[i]) < 23) {
          return true;
        }
      }
    }
    return false;
  }

  void _die() {
    isDead = true;
    game.isBoosting = false;
    for (int i = 0; i < currentSegmentPositions.length; i += 2) {
      game.foodSpawner.spawnOneFood(
        exactPosition: currentSegmentPositions[i],
        customGrowth: 2,
        customColor: i % 4 == 0
            ? const Color(0xFF00F5D4)
            : const Color(0xFF00BBF9),
      );
    }
    game.gameOverNotifier.value = true;
  }

  void _checkFoodEating() {
    const eatRadius = 24.0;
    final foods = game.world.children.whereType<FoodItem>().toList();

    for (final food in foods) {
      final dist = head.position.distanceTo(food.position);
      if (dist <= eatRadius + food.radius) {
        if (food.effectType == FoodEffectType.magnet) {
          _magnetTimer = 6.0;
        } else if (food.effectType == FoodEffectType.boost) {
          _foodBoostTimer = 4.0;
        }
        food.removeFromParent();
        segmentCount += food.growthValue;
        score += food.growthValue * 10;

        game.scoreNotifier.value = score;
        game.lengthNotifier.value = segmentCount;
      }
    }
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
    if (isDead) return;
    final segmentPositions = currentSegmentPositions;

    for (int i = segmentPositions.length - 1; i >= 0; i--) {
      final pos = segmentPositions[i];
      final isHead = i == 0;
      final radius = isHead ? 16.0 : max(8.0, 14.5 - (i * 0.06));

      final paint = Paint()
        ..color = isHead
            ? const Color(0xFF00F5D4)
            : (i % 2 == 0 ? const Color(0xFF00BBF9) : const Color(0xFF3A86FF));

      canvas.drawCircle(Offset(pos.x, pos.y), radius, paint);

      if (isHead) {
        final eyeOffset = Offset(cos(angle) * 6, sin(angle) * 6);
        final eyePaint = Paint()..color = const Color(0xFF0B0F19);
        canvas.drawCircle(Offset(pos.x, pos.y) + eyeOffset, 3.2, eyePaint);
      }
    }
  }

  List<Vector2> _sampleSegmentPositions() {
    final result = <Vector2>[head.position.clone()];
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
