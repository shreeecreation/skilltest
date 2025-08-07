import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/data_point.dart';

class EnergyTempChart extends StatefulWidget {
  const EnergyTempChart({super.key});

  @override
  EnergyTempChartState createState() => EnergyTempChartState();
}

class EnergyTempChartState extends State<EnergyTempChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _toggleController;
  late Animation<double> _animation;

  bool showWeekly = false;
  bool show2024 = true;
  bool show2025 = true;

  List<DataPoint> dataPoints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    );
    _toggleController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Load data from JSON file
    _loadDataFromJson();
  }

  Future<void> _loadDataFromJson() async {
    try {
      // Load the JSON file from assets
      final String response = await rootBundle.loadString('/entry_data.json');
      final Map<String, dynamic> data = json.decode(response);

      // Parse the data points
      final List<dynamic> dataList = data['data_points'];
      setState(() {
        dataPoints = dataList.map((item) => DataPoint.fromJson(item)).toList();
        isLoading = false;
      });

      // Start animation after data is loaded
      _animationController.forward();
    } catch (e) {
      print('Error loading data: $e');
      // Fallback to sample data if JSON loading fails
      // _loadSampleData();
    }
  }

  // void _loadSampleData() {
  //   // This is fallback data only if JSON loading fails
  //   setState(() {
  //     dataPoints = [
  //       // Minimal fallback data - you should use JSON instead
  //       DataPoint(temperature: 0, energy: 300, year: 2024),
  //       DataPoint(temperature: 10, energy: 200, year: 2024),
  //       DataPoint(temperature: 20, energy: 100, year: 2025),
  //       DataPoint(temperature: -5, energy: 400, year: 2025),
  //     ];
  //     isLoading = false;
  //   });
  //   _animationController.forward();
  // }

  @override
  void dispose() {
    _animationController.dispose();
    _toggleController.dispose();
    super.dispose();
  }

  void _togglePeriod() {
    setState(() {
      showWeekly = !showWeekly;
    });
    if (showWeekly) {
      _toggleController.forward();
    } else {
      _toggleController.reverse();
    }
  }

  void _toggle2024() {
    setState(() {
      show2024 = !show2024;
    });
  }

  void _toggle2025() {
    setState(() {
      show2025 = !show2025;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Energi vs Temperatur',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              SizedBox(height: 20),

              // Toggle Buttons
              Row(
                children: [
                  _buildToggleButton(
                    'Ukentlig',
                    !showWeekly,
                    () => _togglePeriod(),
                  ),
                  SizedBox(width: 12),
                  _buildToggleButton(
                    'Daglig',
                    showWeekly,
                    () => _togglePeriod(),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Chart Title
              Center(
                child: Text(
                  'Energi vs Temperatur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Loading indicator or chart
              if (isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ChartPainter(
                          dataPoints:
                              dataPoints, // Using loaded dataPoints, not sampleData
                          animation: _animation.value,
                          show2024: show2024,
                          show2025: show2025,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                ),

              SizedBox(height: 20),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggle2024,
                    child: _buildLegendItem(Colors.green, '2024', show2024),
                  ),
                  SizedBox(width: 20),
                  GestureDetector(
                    onTap: _toggle2025,
                    child: _buildLegendItem(Colors.orange, '2025', show2025),
                  ),
                ],
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isVisible) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isVisible ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isVisible ? color : color.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double animation;
  final bool show2024;
  final bool show2025;

  ChartPainter({
    required this.dataPoints,
    required this.animation,
    required this.show2024,
    required this.show2025,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Chart margins
    final margin = 60.0;
    final chartWidth = size.width - 2 * margin;
    final chartHeight = size.height - 2 * margin;

    // Draw grid
    _drawGrid(canvas, size, margin, chartWidth, chartHeight);

    // Draw axes
    _drawAxes(canvas, size, margin, chartWidth, chartHeight);

    // Draw data points
    _drawDataPoints(canvas, size, margin, chartWidth, chartHeight);
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double margin,
    double chartWidth,
    double chartHeight,
  ) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Vertical grid lines
    for (int i = 0; i <= 7; i++) {
      final x = margin + (i * chartWidth / 7);
      canvas.drawLine(
        Offset(x, margin),
        Offset(x, margin + chartHeight),
        gridPaint,
      );
    }

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = margin + (i * chartHeight / 5);
      canvas.drawLine(
        Offset(margin, y),
        Offset(margin + chartWidth, y),
        gridPaint,
      );
    }
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    double margin,
    double chartWidth,
    double chartHeight,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // X-axis labels (Temperature)
    for (int i = 0; i <= 7; i++) {
      final temp = -10 + (i * 35 / 7);
      final x = margin + (i * chartWidth / 7);

      textPainter.text = TextSpan(
        text: temp.toInt().toString(),
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, margin + chartHeight + 10),
      );
    }

    // Y-axis labels (Energy)
    for (int i = 0; i <= 5; i++) {
      final energy = (5 - i) * 100; // 500k to 0
      final y = margin + (i * chartHeight / 5);

      textPainter.text = TextSpan(
        text: '${energy}k',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(margin - textPainter.width - 10, y - textPainter.height / 2),
      );
    }

    // Axis titles
    textPainter.text = TextSpan(
      text: 'Temperatur (°C)',
      style: TextStyle(color: Colors.white70, fontSize: 14),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height - 20),
    );

    // Y-axis title (rotated)
    textPainter.text = TextSpan(
      text: 'MWh',
      style: TextStyle(color: Colors.white70, fontSize: 14),
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(20, (size.height + textPainter.width) / 2);
    canvas.rotate(-math.pi / 2);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawDataPoints(
    Canvas canvas,
    Size size,
    double margin,
    double chartWidth,
    double chartHeight,
  ) {
    final visiblePoints = dataPoints.where((point) {
      return (point.year == 2024 && show2024) ||
          (point.year == 2025 && show2025);
    }).toList();

    // Calculate how many points to show based on animation progress
    final totalPoints = visiblePoints.length;
    final pointsToShow = (animation * totalPoints).floor();

    for (int i = 0; i < pointsToShow && i < visiblePoints.length; i++) {
      final point = visiblePoints[i];

      final x = margin + ((point.temperature + 10) / 35) * chartWidth;
      final y = margin + chartHeight - (point.energy / 500) * chartHeight;

      // Simple dot appearance
      final baseColor = point.year == 2024 ? Colors.green : Colors.orange;

      // Main point
      final paint = Paint()
        ..color = baseColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4.0, paint);

      // Simple glow effect
      final glowPaint = Paint()
        ..color = baseColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 6.0, glowPaint);
    }

    // Show the currently appearing dot with a fade-in effect
    if (pointsToShow < totalPoints) {
      final currentPoint = visiblePoints[pointsToShow];
      final fadeProgress = (animation * totalPoints) - pointsToShow;

      final x = margin + ((currentPoint.temperature + 10) / 35) * chartWidth;
      final y =
          margin + chartHeight - (currentPoint.energy / 500) * chartHeight;

      final baseColor = currentPoint.year == 2024
          ? Colors.green
          : Colors.orange;

      // Fading in point
      final fadePaint = Paint()
        ..color = baseColor.withOpacity(fadeProgress * 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4.0 * fadeProgress, fadePaint);

      // Fading glow
      final fadeGlowPaint = Paint()
        ..color = baseColor.withOpacity(fadeProgress * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 6.0 * fadeProgress, fadeGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
