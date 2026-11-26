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
  double _pulsePhase = 0;
  late final Paragraph _cachedParagraph;

  FoodItem({
    required Vector2 position,
    required this.growthValue,
    required this.color,
    required this.radius,
    this.effectType = FoodEffectType.normal,
    this.emoji = '🍎',
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
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 5;
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
}

class FoodSpawner extends Component with HasGameReference<WormsArenaGame> {
  final Random _random = Random();
  final int targetFoodCount;
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
    _spawnCheckTimer += dt;
    if (_spawnCheckTimer < 0.25) return;
    _spawnCheckTimer = 0;

    final currentFoods = game.world.children.whereType<FoodItem>().length;
    if (currentFoods < targetFoodCount) {
      final missing = min(25, targetFoodCount - currentFoods);
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

    final chosenEmoji = _foodEmojis[_random.nextInt(_foodEmojis.length)];

    game.world.add(
      FoodItem(
        position: pos,
        growthValue: growth,
        color: chosenColor,
        radius: rad,
        effectType: effect,
        emoji: chosenEmoji,
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
