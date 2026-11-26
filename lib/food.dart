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
  double _pulsePhase = 0;

  FoodItem({
    required Vector2 position,
    required this.growthValue,
    required this.color,
    required this.radius,
    this.effectType = FoodEffectType.normal,
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

    _renderSmiley(canvas, currentRadius);
  }

  void _renderSmiley(Canvas canvas, double r) {
    final facePaint = Paint()
      ..color = const Color(0xFF0B0F19)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, r * 0.14)
      ..strokeCap = StrokeCap.round;

    final eyeFillPaint = Paint()..color = const Color(0xFF0B0F19);
    final eyeOffsetX = r * 0.34;
    final eyeOffsetY = -r * 0.18;
    final eyeRadius = max(1.1, r * 0.12);

    canvas.drawCircle(Offset(-eyeOffsetX, eyeOffsetY), eyeRadius, eyeFillPaint);
    canvas.drawCircle(Offset(eyeOffsetX, eyeOffsetY), eyeRadius, eyeFillPaint);

    final smileRect = Rect.fromCenter(
      center: Offset(0, r * 0.08),
      width: r * 0.95,
      height: r * 0.65,
    );

    if (effectType == FoodEffectType.magnet) {
      canvas.drawArc(smileRect, 0.2, pi - 0.4, false, facePaint);
    } else if (effectType == FoodEffectType.boost) {
      canvas.drawArc(smileRect, 0.1, pi - 0.2, false, facePaint);
    } else {
      canvas.drawArc(smileRect, 0.15, pi - 0.3, false, facePaint);
    }
  }
}

class FoodSpawner extends Component with HasGameReference<WormsArenaGame> {
  final Random _random = Random();
  final int targetFoodCount;

  FoodSpawner({this.targetFoodCount = 420});

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
      final missing = min(15, targetFoodCount - currentFoods);
      for (int i = 0; i < missing; i++) {
        spawnOneFood();
      }
    }
  }

  void spawnOneFood({
    Vector2? exactPosition,
    int? customGrowth,
    Color? customColor,
    FoodEffectType? customEffect,
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

    if (customColor != null) {
      chosenColor = customColor;
    } else if (customEffect == null) {
      final roll = _random.nextDouble();
      if (roll < 0.08) {
        effect = FoodEffectType.magnet;
        chosenColor = const Color(0xFF00BBF9);
      } else if (roll < 0.16) {
        effect = FoodEffectType.boost;
        chosenColor = const Color(0xFFFF006E);
      } else {
        effect = FoodEffectType.normal;
        chosenColor = palette[_random.nextInt(palette.length)];
      }
    } else {
      chosenColor = effect == FoodEffectType.magnet
          ? const Color(0xFF00BBF9)
          : (effect == FoodEffectType.boost
              ? const Color(0xFFFF006E)
              : palette[_random.nextInt(palette.length)]);
    }

    game.world.add(
      FoodItem(
        position: pos,
        growthValue: growth,
        color: chosenColor,
        radius: rad,
        effectType: effect,
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
