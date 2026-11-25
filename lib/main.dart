import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:worms_arena/food.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<WormsArenaGame>.controlled(
          gameFactory: WormsArenaGame.new,
        ),
      ),
    ),
  );
}

class WormsArenaGame extends FlameGame with PanDetector {
  static const double arenaRadius = 1400;
  static const double normalSpeed = 195;
  static const double baseSegmentSpacing = 12;

  late final WormPlayer worm;
  late final FoodSpawner foodSpawner;
  Vector2? targetDirection;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> lengthNotifier = ValueNotifier<int>(12);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.add(ArenaBackground(radius: arenaRadius));

    foodSpawner = FoodSpawner(targetFoodCount: 140);
    world.add(foodSpawner);

    worm = WormPlayer(startPosition: Vector2.zero());
    world.add(worm);
    camera.follow(worm.head);

    scoreNotifier.value = 0;
    lengthNotifier.value = worm.segmentCount;
  }

  @override
  void onPanStart(DragDownInfo info) {
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

  ArenaBackground({required this.radius});

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFF101522);
    canvas.drawCircle(Offset.zero, radius + 300, bgPaint);

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

    final borderPaint = Paint()
      ..color = const Color(0xFFFF4D6D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(Offset.zero, radius, borderPaint);
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
  final List<Vector2> pathHistory = [];

  WormPlayer({required Vector2 startPosition})
      : head = WormHeadAnchor(position: startPosition);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(head);
    for (int i = 0; i < 400; i++) {
      pathHistory.add(head.position.clone());
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final desiredDir = game.targetDirection;
    if (desiredDir != null && desiredDir.length > 0) {
      final targetAngle = atan2(desiredDir.y, desiredDir.x);
      final diff = _normalizeAngle(targetAngle - angle);
      const maxTurnSpeed = 5.5;
      angle += diff.clamp(-maxTurnSpeed * dt, maxTurnSpeed * dt);
      angle = _normalizeAngle(angle);
    }

    final velocity = Vector2(cos(angle), sin(angle)) * WormsArenaGame.normalSpeed;
    head.position += velocity * dt;

    final distFromCenter = head.position.length;
    final maxR = WormsArenaGame.arenaRadius - 24;
    if (distFromCenter > maxR) {
      head.position = head.position.normalized() * maxR;
    }

    _checkFoodEating();

    pathHistory.insert(0, head.position.clone());

    final maxPoints = (segmentCount * WormsArenaGame.baseSegmentSpacing / 2).ceil() + 60;
    if (pathHistory.length > maxPoints) {
      pathHistory.removeRange(maxPoints, pathHistory.length);
    }
  }

  void _checkFoodEating() {
    const eatRadius = 24.0;
    final foods = game.world.children.whereType<FoodItem>().toList();

    for (final food in foods) {
      final dist = head.position.distanceTo(food.position);
      if (dist <= eatRadius + food.radius) {
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
    final segmentPositions = _sampleSegmentPositions();

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
