  import 'package:flutter/material.dart';
  import 'package:go_router/go_router.dart';
  import 'package:provider/provider.dart';
  import 'package:visualpremium/providers/data_provider.dart';
  import 'dart:math' as math;

  class SplashPage extends StatefulWidget {
    const SplashPage({super.key});

    @override
    State<SplashPage> createState() => _SplashPageState();
  }

  class _SplashPageState extends State<SplashPage>
      with TickerProviderStateMixin {
    late AnimationController _logoController;
    late AnimationController _fadeController;
    late AnimationController _progressController;
    late AnimationController _particlesController;

    late Animation<double> _logoScale;
    late Animation<double> _logoRotation;
    late Animation<double> _fadeAnimation;
    late Animation<double> _progressAnimation;

    bool _dataLoaded = false;
    bool _animationsComplete = false;

    @override
    void initState() {
      super.initState();

      // Logo animation controller
      _logoController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      // Fade animation controller
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      // Progress animation controller
      _progressController = AnimationController(
        duration: const Duration(milliseconds: 2500),
        vsync: this,
      );

      // Particles animation controller
      _particlesController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat();

      // Logo scale animation
      _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _logoController,
          curve: Curves.elasticOut,
        ),
      );

      // Logo rotation animation
      _logoRotation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
        CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        ),
      );

      // Fade animation
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fadeController,
          curve: Curves.easeIn,
        ),
      );

      // Progress animation
      _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeInOut,
        ),
      );

      // Start animations and data loading
      _startAnimationsAndLoadData();
    }

    void _startAnimationsAndLoadData() async {
      // Start logo animation
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _logoController.forward();

      // Start fade animation
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _fadeController.forward();

      // Start progress animation
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _progressController.forward();

      // Load data in parallel with animations
      _loadData();

      // Mark animations as complete after minimum time
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      setState(() {
        _animationsComplete = true;
      });
      _checkAndNavigate();
    }

    void _loadData() async {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      try {
        await dataProvider.loadAllData();
        if (!mounted) return;
        setState(() {
          _dataLoaded = true;
        });
        _checkAndNavigate();
      } catch (e) {
        // Em caso de erro, ainda navega após timeout
        if (!mounted) return;
        setState(() {
          _dataLoaded = true; // Marca como carregado mesmo com erro
        });
        _checkAndNavigate();
      }
    }

    void _checkAndNavigate() {
      // Só navega quando ambos estiverem completos
      if (_dataLoaded && _animationsComplete && mounted) {
        // Pequeno delay para suavizar a transição
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            context.go('/');
          }
        });
      }
    }

    @override
    void dispose() {
      _logoController.dispose();
      _fadeController.dispose();
      _progressController.dispose();
      _particlesController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      final size = MediaQuery.of(context).size;

      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? [
                      const Color(0xFF1a1818),
                      const Color(0xFF2d2020),
                      const Color(0xFF1a1818),
                    ]
                  : [
                      const Color(0xFFffffff),
                      const Color(0xFFfff5f0),
                      const Color(0xFFffe8dc),
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Animated particles background
              AnimatedBuilder(
                animation: _particlesController,
                builder: (context, child) {
                  return CustomPaint(
                    size: size,
                    painter: ParticlesPainter(
                      animation: _particlesController.value,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value,
                          child: Transform.rotate(
                            angle: _logoRotation.value,
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // App name with fade animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Visual Premium',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
        
                    const SizedBox(height: 60),

                    // Animated progress bar
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Column(
                          children: [
                            Container(
                              width: 200,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.primary.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                _dataLoaded ? 'Pronto!' : 'Carregando...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Floating orbs
              Positioned(
                top: size.height * 0.15,
                left: size.width * 0.1,
                child: AnimatedBuilder(
                  animation: _particlesController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.sin(_particlesController.value * 2 * math.pi) * 20,
                        math.cos(_particlesController.value * 2 * math.pi) * 20,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                              theme.colorScheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Positioned(
                bottom: size.height * 0.2,
                right: size.width * 0.15,
                child: AnimatedBuilder(
                  animation: _particlesController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        math.cos(_particlesController.value * 2 * math.pi) * 15,
                        math.sin(_particlesController.value * 2 * math.pi) * 15,
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.secondary.withValues(alpha: 0.15),
                              theme.colorScheme.secondary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  class ParticlesPainter extends CustomPainter {
    final double animation;
    final Color color;

    ParticlesPainter({required this.animation, required this.color});

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Draw multiple particles
      for (int i = 0; i < 20; i++) {
        final offset = Offset(
          (size.width / 20) * i + math.sin(animation * 2 * math.pi + i) * 30,
          (size.height / 20) * i + math.cos(animation * 2 * math.pi + i) * 30,
        );

        final radius = 2.0 + math.sin(animation * 2 * math.pi + i) * 1.5;
        canvas.drawCircle(offset, radius, paint);
      }
    }

    @override
    bool shouldRepaint(ParticlesPainter oldDelegate) {
      return oldDelegate.animation != animation;
    }
  }