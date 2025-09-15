// lib/core/ml/image_utils.dart
import 'package:camera/camera.dart';

/// CameraImage(YUV420) → CHW(224x224x3) float32 [0..1]
List<double> yuv420ToCHW224(
    CameraImage img, {
      bool mirror = false,
      int rotate = 0, // 지원: 0,90,180,270
    }) {
  final w = img.width, h = img.height;
  final yPlane = img.planes[0];
  final uPlane = img.planes[1];
  final vPlane = img.planes[2];

  int clampi(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  // (ox,oy) 출력 좌표 → 원본 좌표(sx,sy)로 매핑 (회전+미러 적용)
  void mapXY(int x, int y, void Function(int sx, int sy) put) {
    int sx = x, sy = y;

    // 회전
    if (rotate == 90) {
      final tx = y;
      final ty = w - 1 - x;
      sx = tx; sy = ty;
    } else if (rotate == 180) {
      sx = w - 1 - x; sy = h - 1 - y;
    } else if (rotate == 270) {
      final tx = h - 1 - y;
      final ty = x;
      sx = tx; sy = ty;
    }

    // 미러 (수평 뒤집기)
    if (mirror) {
      if (rotate == 90 || rotate == 270) {
        // 90/270에서는 가로축이 h 기준
        sx = (rotate == 90) ? (h - 1 - sx) : (h - 1 - sx);
      } else {
        sx = w - 1 - sx;
      }
    }

    sx = (rotate == 90 || rotate == 270) ? clampi(sx, 0, h - 1) : clampi(sx, 0, w - 1);
    sy = (rotate == 90 || rotate == 270) ? clampi(sy, 0, w - 1) : clampi(sy, 0, h - 1);
    put(sx, sy);
  }

  const out = 224;
  final rC = List<double>.filled(out * out, 0.0);
  final gC = List<double>.filled(out * out, 0.0);
  final bC = List<double>.filled(out * out, 0.0);

  final yRowStride = yPlane.bytesPerRow;
  final uRowStride = uPlane.bytesPerRow;
  final vRowStride = vPlane.bytesPerRow;
  final uPixStride = uPlane.bytesPerPixel ?? 1;
  final vPixStride = vPlane.bytesPerPixel ?? 1;

  for (int oy = 0; oy < out; oy++) {
    for (int ox = 0; ox < out; ox++) {
      // 원본 최근접 샘플링 좌표
      final fx = ((ox + 0.5) * w / out) - 0.5;
      final fy = ((oy + 0.5) * h / out) - 0.5;
      int nx = clampi(fx.round(), 0, w - 1);
      int ny = clampi(fy.round(), 0, h - 1);

      int sx = nx, sy = ny;
      mapXY(nx, ny, (mx, my) { sx = mx; sy = my; });

      // Y
      final yIndex = sy * yRowStride + sx;
      final Y = yPlane.bytes[yIndex].toDouble();

      // UV (4:2:0)
      final uvx = (sx / 2).floor();
      final uvy = (sy / 2).floor();
      final uIndex = uvy * uRowStride + uvx * uPixStride;
      final vIndex = uvy * vRowStride + uvx * vPixStride;
      final U = (uPlane.bytes[uIndex].toDouble() - 128.0);
      final V = (vPlane.bytes[vIndex].toDouble() - 128.0);

      // BT.601 → RGB
      double R = Y + 1.402 * V;
      double G = Y - 0.344136 * U - 0.714136 * V;
      double B = Y + 1.772 * U;

      // [0..1] 정규화
      R = (R / 255.0).clamp(0.0, 1.0);
      G = (G / 255.0).clamp(0.0, 1.0);
      B = (B / 255.0).clamp(0.0, 1.0);

      final di = oy * out + ox;
      rC[di] = R;
      gC[di] = G;
      bC[di] = B;
    }
  }

  // CHW로 반환
  return <double>[...rC, ...gC, ...bC];
}
