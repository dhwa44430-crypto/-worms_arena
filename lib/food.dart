import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:worms_arena/main.dart';

class FoodItem extends PositionComponent with HasGameReference<WormsArenaGame> {
  final int growthValue;
  final Color color;
  final double radius;
  double _pulsePhase = 0;

  FoodItem({
    required Vector2 position,
    required this.growthValue,
    required this.color,
    required this.radius,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 5;
  }

  @override
  void render(Canvas canvas) {
    final pulseScale = 1.0 + (sin(_pulsePhase) * 0.12);
    final currentRadius = radius * pulseScale;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset.zero, currentRadius * 1.4, glowPaint);

    final corePaint = Paint()..color = color;
    canvas.drawCircle(Offset.zero, currentRadius, corePaint);
  }
}

class FoodSpawner extends Component with HasGameReference<WormsArenaGame> {
  final Random _random = Random();
  final int targetFoodCount;

  FoodSpawner({this.targetFoodCount = 140});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < targetFoodCount; i++) {
      spawnOneFood();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final currentFoods = game.world.children.whereType<FoodItem>().length;
    if (currentFoods < targetFoodCount) {
      final missing = min(5, targetFoodCount - currentFoods);
      for (int i = 0; i < missing; i++) {
        spawnOneFood();
      }
    }
  }

  void spawnOneFood({Vector2? exactPosition, int? customGrowth, Color? customColor}) {
    final pos = exactPosition ?? _randomArenaPoint();
    final isBig = _random.nextDouble() < 0.18;
    final growth = customGrowth ?? (isBig ? 2 : 1);
    final rad = customColor != null
        ? 8.5
        : (isBig ? 8.0 : 5.5);

    const palette = [
      Color(0xFFFFBE0B),
      Color(0xFFFB5607),
      Color(0xFFFF006E),
      Color(0xFF8338EC),
      Color(0xFF06D6A0),
    ];

    final chosenColor = customColor ?? palette[_random.nextInt(palette.length)];

    game.world.add(
      FoodItem(
        position: pos,
        growthValue: growth,
        color: chosenColor,
        radius: rad,
      ),
    );
  }

  Vector2 _randomArenaPoint() {
    final r = sqrt(_random.nextDouble()) * (WormsArenaGame.arenaRadius - 60);
    final theta = _random.nextDouble() * 2 * pi;
    return Vector2(cos(theta) * r, sin(theta) * r);
  }
}
