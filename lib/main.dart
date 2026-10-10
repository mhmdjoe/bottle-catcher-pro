import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BottleCatcherApp());
}

// --- GAME CONFIGURATION ---
// Add your 3 photos to the 'assets' folder and name them below!
const List<String> celebrationAssets = [
  'assets/photo1.png',
  'assets/photo2.png',
  'assets/photo3.png',
];
// ---------------------------

enum GameState { initial, playing, gameOver }

class BottleCatcherApp extends StatelessWidget {
  const BottleCatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bottle Catcher Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  GameState _gameState = GameState.initial;
  
  double _playerX = 0.5;
  List<Bottle> _bottles = [];
  List<Particle> _particles = [];
  List<FloatingText> _floatingTexts = [];
  
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  double _gameSpeed = 3.0; // Increased base speed
  bool _milestoneReached = false;
  double _shakeIntensity = 0.0;
  int _ticksSinceLastSpawn = 0; // Prevent overlapping bottles
  Duration _lastTick = Duration.zero;
  
  final Random _random = Random();
  final FocusNode _focusNode = FocusNode();
  double _screenWidth = 0;
  double _screenHeight = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadHighScore();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _updateHighScore() async {
    if (_score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', _score);
      setState(() {
        _highScore = _score;
      });
    }
  }

  void _onTick(Duration elapsed) {
    final double dt = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;

    if (_gameState != GameState.playing) return;

    setState(() {
      // 1. Update Shake
      if (_shakeIntensity > 0) _shakeIntensity *= 0.9;

      // 2. Move bottles (Frame-Independent)
      // Speed is defined as % of screen height per second
      for (var bottle in _bottles) {
        bottle.y += _gameSpeed * 0.20 * dt; // Increased from 0.08 for faster, snappier movement
      }

      // 3. Update Particles
      _particles.removeWhere((p) {
        p.update(dt);
        return p.life <= 0;
      });

      // 4. Update Floating Texts
      _floatingTexts.removeWhere((t) {
        t.update(dt);
        return t.life <= 0;
      });

      // 5. Collision & Miss Logic
      _bottles.removeWhere((bottle) {
        // Catch Detection (Triggers when bottle bottom touches crate top)
        // Adjusting y window to ~0.78 to account for bottle height (40px)
        if (!bottle.caught && bottle.y >= 0.77 && bottle.y <= 0.81) {
          const double playerWidth = 0.2; 
          if ((bottle.x - _playerX).abs() < playerWidth / 2) {
            bottle.caught = true;
            _handleCatch(bottle);
          }
        }

        // Remove after it has visually fallen "into" the crate (y ~ 0.85)
        if (bottle.caught && bottle.y > 0.85) return true;
        
        if (!bottle.caught && bottle.y > 1.0) {
          _handleMiss();
          return true;
        }
        return false;
      });

      // 6. Spawn bottles with spacing logic
      _ticksSinceLastSpawn++;
      double spawnChance = 0.015 + (_gameSpeed / 400);
      int minGap = (50 / (_gameSpeed / 2)).round().clamp(15, 50); // Dynamic gap based on speed

      if (_ticksSinceLastSpawn > minGap && _random.nextDouble() < spawnChance) {
        double newX = 0.1 + _random.nextDouble() * 0.8;
        
        // Ensure not spawning exactly where another top-bottle is
        bool tooClose = _bottles.any((b) => b.y < 0.2 && (b.x - newX).abs() < 0.15);
        
        if (!tooClose) {
          _bottles.add(Bottle(
            x: newX,
            y: -0.1,
          ));
          _ticksSinceLastSpawn = 0;
        }
      }
    });
  }

  void _handleCatch(Bottle bottle) {
    _score++;
    HapticFeedback.lightImpact();
    
    // Add Floating Text
    _floatingTexts.add(FloatingText(x: _playerX, y: 0.8));
    
    // Add Particles
    for (int i = 0; i < 8; i++) {
      _particles.add(Particle(x: _playerX, y: 0.85));
    }

    if (_score % 15 == 0) {
      _milestoneReached = true;
      _gameSpeed += 0.3;
    }
    _gameSpeed += (_score > 15) ? 0.1 : 0.05;
  }

  void _handleMiss() {
    _lives--;
    _shakeIntensity = 15.0; // Trigger screen shake
    HapticFeedback.vibrate();
    
    if (_lives <= 0) {
      _gameState = GameState.gameOver;
      _ticker.stop();
      _updateHighScore();
    }
  }

  void _startGame() {
    setState(() {
      _bottles = [];
      _particles = [];
      _floatingTexts = [];
      _score = 0;
      _lives = 3;
      _milestoneReached = false;
      _gameState = GameState.playing;
      _gameSpeed = 3.0; // Starts faster on restart
      _playerX = 0.5;
      _shakeIntensity = 0.0;
      _ticksSinceLastSpawn = 0;
      _lastTick = Duration.zero; // Reset tick timing
    });
    _focusNode.requestFocus();
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _screenWidth = constraints.maxWidth;
        _screenHeight = constraints.maxHeight;

        // Calculate shake offset
        double shakeX = (_random.nextDouble() - 0.5) * _shakeIntensity;
        double shakeY = (_random.nextDouble() - 0.5) * _shakeIntensity;

        return Scaffold(
          backgroundColor: Colors.black,
          body: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (_gameState != GameState.playing) return;
              const double step = 0.05;
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                setState(() {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) {
                    _playerX = (_playerX - step).clamp(0.1, 0.9);
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) {
                    _playerX = (_playerX + step).clamp(0.1, 0.9);
                  }
                });
              }
            },
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_gameState != GameState.playing) return;
                setState(() {
                  _playerX += details.primaryDelta! / _screenWidth;
                  _playerX = _playerX.clamp(0.1, 0.9);
                });
              },
              child: Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800, Colors.brown.shade900],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Luxury Background: Floating Bubbles
                      ...List.generate(15, (index) => _BackgroundBubble(index: index, height: _screenHeight, width: _screenWidth)),

                      // Milestone Character
                      if (_milestoneReached && _gameState == GameState.playing)
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _CelebrationCharacter(score: _score)),
                        ),

                      // Particles
                      ..._particles.map((p) => Positioned(
                        left: p.x * _screenWidth,
                        top: p.y * _screenHeight,
                        child: Opacity(
                          opacity: p.life,
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          ),
                        ),
                      )),

                      // Floating Texts
                      ..._floatingTexts.map((t) => Positioned(
                        left: t.x * _screenWidth,
                        top: t.y * _screenHeight,
                        child: Opacity(
                          opacity: t.life,
                          child: const Text('+1', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      )),

                      // Game UI
                      if (_gameState != GameState.initial)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              children: [
                                Flexible(child: _buildStatCard('SCORE', '$_score', Colors.amber)),
                                const SizedBox(width: 10),
                                Flexible(child: _buildStatCard('LIVES', '❤️' * _lives, Colors.redAccent)),
                              ],
                            ),
                          ),
                        ),

                      // Bottles
                      ..._bottles.map((bottle) => Positioned(
                        left: bottle.x * _screenWidth - 25,
                        top: bottle.y * _screenHeight,
                        child: const _BottleWidget(),
                      )),

                      // Player
                      Positioned(
                        bottom: _screenHeight * 0.1,
                        left: _playerX * _screenWidth - 50,
                        child: const _PlayerWidget(),
                      ),

                      // Overlays
                      if (_gameState == GameState.initial) Positioned.fill(child: _buildMenuOverlay()),
                      if (_gameState == GameState.gameOver) Positioned.fill(child: _buildGameOverOverlay()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FittedBox(child: Text('BOTTLE CATCHER\nPRO', textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 4))),
              const SizedBox(height: 20),
              Text('HIGH SCORE: $_highScore', style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              _MenuButton(label: 'START GAME', onPressed: _startGame, color: Colors.amber),
              const SizedBox(height: 20),
              const Text('Catch the falling bottles!\nArrow Keys / A-D / Drag', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FittedBox(child: Text('GAME OVER', style: TextStyle(color: Colors.redAccent, fontSize: 64, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              Text('FINAL SCORE: $_score', style: const TextStyle(color: Colors.white, fontSize: 32)),
              const SizedBox(height: 8),
              Text('HIGH SCORE: $_highScore', style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              _MenuButton(label: 'PLAY AGAIN', onPressed: _startGame, color: Colors.amber),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundBubble extends StatelessWidget {
  final int index;
  final double height;
  final double width;
  const _BackgroundBubble({required this.index, required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: -50,
      left: (index * 0.13) % 1.0 * width,
      child: _TweenBubble(delay: index * 0.5, height: height),
    );
  }
}

class _TweenBubble extends StatefulWidget {
  final double delay;
  final double height;
  const _TweenBubble({required this.delay, required this.height});
  @override
  State<_TweenBubble> createState() => _TweenBubbleState();
}

class _TweenBubbleState extends State<_TweenBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double progress = (_controller.value + (widget.delay / 10)) % 1.0;
        return Opacity(
          opacity: (1.0 - progress) * 0.2,
          child: Transform.translate(
            offset: Offset(sin(progress * 10) * 20, -progress * widget.height),
            child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
          ),
        );
      },
    );
  }
}

class _CelebrationCharacter extends StatefulWidget {
  final int score;
  const _CelebrationCharacter({required this.score});
  @override
  State<_CelebrationCharacter> createState() => _CelebrationCharacterState();
}

class _CelebrationCharacterState extends State<_CelebrationCharacter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _sway;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _sway = Tween<double>(begin: -0.03, end: 0.03).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Determine which asset to show based on score (every 15 bottles)
    int assetIndex = ((widget.score ~/ 15) - 1).clamp(0, celebrationAssets.length - 1);
    String currentAsset = celebrationAssets[assetIndex];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(scale: _pulse.value, child: Transform.rotate(angle: _sway.value, child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.transparent], stops: [0.85, 1.0]).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SizedBox(width: 350, height: 500, child: Image(key: ValueKey(currentAsset), image: AssetImage(currentAsset), fit: BoxFit.contain)),
          ),
          const SizedBox(height: 5),
          Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24, width: 1)), child: Text('STELLA LEVEL ${assetIndex + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2))),
        ])));
      },
    );
  }
}

class _BottleWidget extends StatelessWidget {
  const _BottleWidget();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)]),
      child: const Text('🍾', style: TextStyle(fontSize: 40)),
    );
  }
}

class _PlayerWidget extends StatelessWidget {
  const _PlayerWidget();
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 110, height: 80, child: Stack(alignment: Alignment.bottomCenter, children: [
      Positioned(top: 5, left: 10, right: 10, child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(4, (index) => Transform.translate(offset: Offset(0, index % 2 == 0 ? 0 : 5), child: const Text('🍾', style: TextStyle(fontSize: 20))))))),
      Container(width: 110, height: 55, decoration: BoxDecoration(color: Colors.brown.shade800, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.brown.shade900, width: 3), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 15, offset: Offset(0, 8))]), child: Stack(children: [
        Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Container(height: 2, color: Colors.brown.shade900), Container(height: 2, color: Colors.brown.shade900)]),
        const Center(child: Text('STELLA', style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2))),
      ])),
    ]));
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  const _MenuButton({required this.label, required this.onPressed, required this.color});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 8), child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));
  }
}

class Bottle { 
  double x; 
  double y; 
  bool caught = false; // Track if the bottle has entered the crate
  Bottle({required this.x, required this.y}); 
}

class Particle {
  double x, y, vx, vy, size, life;
  Particle({required this.x, required this.y}) : vx = (Random().nextDouble() - 0.5) * 1.2, vy = (Random().nextDouble() - 0.5) * 1.2, size = Random().nextDouble() * 8 + 2, life = 1.0;
  void update(double dt) { x += vx * dt; y += vy * dt; life -= 1.8 * dt; }
}

class FloatingText {
  double x, y, life;
  FloatingText({required this.x, required this.y}) : life = 1.0;
  void update(double dt) { y -= 0.3 * dt; life -= 1.2 * dt; }
}
