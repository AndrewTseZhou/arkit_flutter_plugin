import 'dart:math';
import 'package:flutter/material.dart';

class BrokenSidesRRectPainter extends CustomPainter {
  /// 圆角半径
  final double radius;

  /// 边框宽度
  final double strokeWidth;

  /// 边框颜色
  final Color color;

  /// 构造
  BrokenSidesRRectPainter({
    required this.radius,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 画笔设置：仅绘制线条
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 为了便于阅读，提前准备一些常量
    final w = size.width;
    final h = size.height;
    final r = radius;

    // 每条边要考虑真正的“可绘线段长度” = (总长 - 2*圆角)，
    // 因为左右/上下两端要留给圆角弧。
    final topSideLength    = w - 2 * r;
    final rightSideLength  = h - 2 * r;
    final bottomSideLength = w - 2 * r;
    final leftSideLength   = h - 2 * r;

    // “断开”逻辑：每边只画 1/4 + 1/4，跳过中间 1/2。
    // 比如上边：从 0 到 topSideLength，画 [0 ~ 0.25L], 跳过 [0.25L ~ 0.75L], 再画 [0.75L ~ 1.0L].
    double quarter(double length)      => length * 0.25;
    double threeQuarter(double length) => length * 0.75;

    // 准备一条 Path，按顺时针方向逐个绘制：
    //   (1) 左上角圆弧
    //   (2) 上边(两端)
    //   (3) 右上角圆弧
    //   (4) 右边(两端)
    //   (5) 右下角圆弧
    //   (6) 下边(两端)
    //   (7) 左下角圆弧
    //   (8) 左边(两端)
    // 并不闭合 path，仅靠 stroke 显示外框。

    final path = Path();

    // ---------------------------
    // 1) 左上角圆弧 (从180°到270°)
    // ---------------------------
    // 先移动到圆弧起点(0, r)，再用 arcTo 绘制
    path.moveTo(0, r);
    path.arcTo(
      Rect.fromLTWH(0, 0, 2 * r, 2 * r),  // 左上角的外接矩形
      pi,        // startAngle = 180°
      pi / 2,    // sweepAngle = 90°
      false,
    );
    // 结束时，path 到达 (r, 0)

    // ---------------------------
    // 2) 上边两端
    // ---------------------------
    // 上边直线从 x=r 到 x=(w-r)，全长 topSideLength
    // 分割: [0 ~ 0.25L], [0.75L ~ 1.0L]
    final topQuarter      = quarter(topSideLength);
    final topThreeQuarter = threeQuarter(topSideLength);
    // 第1段: r -> r+topQuarter
    path.lineTo(r + topQuarter, 0);
    // 跳过中间: (r+topQuarter) -> (r+topThreeQuarter)
    path.moveTo(r + topThreeQuarter, 0);
    // 第2段: (r+topThreeQuarter) -> (w-r)
    path.lineTo(w - r, 0);

    // ---------------------------
    // 3) 右上角圆弧 (从270°到360°)
    // ---------------------------
    path.arcTo(
      Rect.fromLTWH(w - 2 * r, 0, 2 * r, 2 * r), // 右上角外接矩形
      1.5 * pi,   // 270°
      pi / 2,     // 90°
      false,
    );
    // 结束时，path 到达 (w, r)

    // ---------------------------
    // 4) 右边两端
    // ---------------------------
    final rightQuarter      = quarter(rightSideLength);
    final rightThreeQuarter = threeQuarter(rightSideLength);
    // 第1段: y=r -> r+rightQuarter
    path.lineTo(w, r + rightQuarter);
    // 跳过中间: (r+rightQuarter) -> (r+rightThreeQuarter)
    path.moveTo(w, r + rightThreeQuarter);
    // 第2段: (r+rightThreeQuarter) -> (h-r)
    path.lineTo(w, h - r);

    // ---------------------------
    // 5) 右下角圆弧 (从0°到90°)
    // ---------------------------
    path.arcTo(
      Rect.fromLTWH(w - 2 * r, h - 2 * r, 2 * r, 2 * r),
      0,       // 0°
      pi / 2,  // 90°
      false,
    );
    // 结束时，path 到达 (w-r, h)

    // ---------------------------
    // 6) 下边两端
    // ---------------------------
    final bottomQuarter      = quarter(bottomSideLength);
    final bottomThreeQuarter = threeQuarter(bottomSideLength);
    // 从 (w-r, h) 向左到 (r, h)，全长 bottomSideLength
    // 第1段: (w-r) -> (w-r - bottomQuarter)
    path.lineTo(w - r - bottomQuarter, h);
    // 跳过中间
    path.moveTo(w - r - bottomThreeQuarter, h);
    // 第2段: -> (r, h)
    path.lineTo(r, h);

    // ---------------------------
    // 7) 左下角圆弧 (从90°到180°)
    // ---------------------------
    path.arcTo(
      Rect.fromLTWH(0, h - 2 * r, 2 * r, 2 * r),
      pi / 2,   // 90°
      pi / 2,   // 90°
      false,
    );
    // 结束时，path 到达 (0, h-r)

    // ---------------------------
    // 8) 左边两端
    // ---------------------------
    final leftQuarter      = quarter(leftSideLength);
    final leftThreeQuarter = threeQuarter(leftSideLength);
    // 从 y=(h-r) 向上到 y=r
    // 第1段
    path.lineTo(0, h - r - leftQuarter);
    // 跳过中间
    path.moveTo(0, h - r - leftThreeQuarter);
    // 第2段
    path.lineTo(0, r);

    // （到此，已经回到左上角圆弧的起点附近，不需要 close 以免连线穿过边框）
    // 最后用 stroke 绘制
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BrokenSidesRRectPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
