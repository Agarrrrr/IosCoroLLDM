import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';

class _Token extends PdfPageRenderCancellationToken {
  bool canceled = false;
  @override
  bool get isCanceled => canceled;
  @override
  void cancel() => canceled = true;
}

class _Document extends PdfDocument {
  _Document({int pageCount = 1, ui.Image? bitmap})
      : super(sourceName: 'deferred-render-regression-$pageCount') {
    pages = List.generate(
        pageCount, (i) => _Page(this, number: i + 1, bitmap: bitmap));
  }
  @override
  late final List<PdfPage> pages;
  @override
  PdfPermissions? get permissions => null;
  @override
  bool get isEncrypted => false;
  @override
  Stream<PdfDocumentEvent> get events => const Stream.empty();
  @override
  Future<void> dispose() async {}
  @override
  Future<void> loadPagesProgressively<T>(
      {PdfPageLoadingCallback<T>? onPageLoadProgress,
      T? data,
      Duration loadUnitDuration = const Duration(milliseconds: 250)}) async {}
  @override
  Future<List<PdfOutlineNode>> loadOutline() async => [];
  @override
  bool isIdenticalDocumentHandle(Object? other) => identical(this, other);
}

class _Page extends PdfPage {
  _Page(this.document, {this.number = 1, this.bitmap});
  final int number;
  final ui.Image? bitmap;
  int baseRenderCount = 0;
  final renders = <Size>[];
  @override
  final PdfDocument document;
  @override
  int get pageNumber => number;
  @override
  double get width => 600;
  @override
  double get height => 840;
  @override
  bool get isLoaded => true;
  @override
  PdfPageRotation get rotation => PdfPageRotation.values.first;
  @override
  PdfPageRenderCancellationToken createCancellationToken() => _Token();
  @override
  Future<PdfImage?> render(
      {int x = 0,
      int y = 0,
      int? width,
      int? height,
      double? fullWidth,
      double? fullHeight,
      Color? backgroundColor,
      PdfAnnotationRenderingMode annotationRenderingMode =
          PdfAnnotationRenderingMode.annotationAndForms,
      int flags = PdfPageRenderFlags.none,
      PdfPageRenderCancellationToken? cancellationToken}) async {
    if (width != null && height != null) {
      renders.add(Size(width.toDouble(), height.toDouble()));
    }
    if (width == null) baseRenderCount++;
    return bitmap == null ? null : _Bitmap(bitmap!);
  }

  @override
  Future<List<PdfLink>> loadLinks(
          {bool compact = false, bool enableAutoLinkDetection = true}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bitmap extends PdfImage {
  _Bitmap(this.image);
  final ui.Image image;
  @override
  int get width => 1;
  @override
  int get height => 1;
  @override
  ui.PixelFormat get format => ui.PixelFormat.rgba8888;
  @override
  Uint8List get pixels => Uint8List.fromList([255, 255, 255, 255]);
  @override
  Future<ui.Image> createImage() async => image.clone();
  @override
  void dispose() {}
}

void main() {
  testWidgets(
      'PDF page filter inverts paper without inverting colored overlays',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final bitmap = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.white, BlendMode.src);
      final picture = recorder.endRecording();
      final result = await picture.toImage(1, 1);
      picture.dispose();
      return result;
    }))!;
    final document = _Document(bitmap: bitmap);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: key,
            child: PdfViewer(PdfDocumentRefDirect(document),
                params: PdfViewerParams(
                  enableTextSelection: false,
                  pageColorFilter: PdfThemePalette.invertFilter,
                  backgroundColor: Colors.black,
                  pageDropShadow: null,
                  pageOverlaysBuilder: (context, rect, page) => [
                    Positioned(
                        left: rect.width / 2 - 5,
                        top: rect.height / 2 - 5,
                        child: const SizedBox(
                            width: 10,
                            height: 10,
                            child: ColoredBox(color: Colors.red))),
                  ],
                )))));
    await tester.pumpAndSettle();
    final bytes = (await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    var red = 0;
    var black = 0;
    var cyan = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] > 220 && bytes[i + 1] < 100 && bytes[i + 2] < 100) red++;
      if (bytes[i] < 10 && bytes[i + 1] < 10 && bytes[i + 2] < 10) black++;
      if (bytes[i] < 100 && bytes[i + 1] > 220 && bytes[i + 2] > 220) cyan++;
    }
    expect(red, greaterThan(50));
    expect(black, greaterThan(100000));
    expect(cyan, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    bitmap.dispose();
  });
  testWidgets(
      'background page geometry keeps the visible page zoom and position',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final document = _Document(pageCount: 2);
    final reference = PdfDocumentRefDirect(document);
    final controller = PdfViewerController();
    var trailingWidth = 600.0;
    Future<void> mount() => tester.pumpWidget(MaterialApp(
        home: PdfViewer(reference,
            controller: controller,
            params: PdfViewerParams(
                enableTextSelection: false,
                maxScale: 6,
                layoutPages: (pages, params) => PdfPageLayout(pageLayouts: [
                      Rect.fromLTWH((trailingWidth - 600) / 2, 0, 600, 840),
                      Rect.fromLTWH(0, 900, trailingWidth, 840),
                    ], documentSize: Size(trailingWidth, 1740))))));
    await mount();
    await tester.pumpAndSettle();
    controller.value = Matrix4.identity()
      ..translate(-90.0, -130.0)
      ..scale(2.0);
    await tester.pumpAndSettle();
    final beforeZoom = controller.currentZoom;
    final before = controller.visibleRect.center -
        controller.layout.pageLayouts.first.topLeft;
    trailingWidth = 900;
    await mount();
    await tester.pumpAndSettle();
    final after = controller.visibleRect.center -
        controller.layout.pageLayouts.first.topLeft;
    expect(controller.currentZoom, closeTo(beforeZoom, 1e-6));
    expect(after.dx, closeTo(before.dx, 1e-6));
    expect(after.dy, closeTo(before.dy, 1e-6));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('returning to a page reuses a cache that is below its limit',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final bitmap = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.white, BlendMode.src);
      final picture = recorder.endRecording();
      final result = await picture.toImage(1, 1);
      picture.dispose();
      return result;
    }))!;
    addTearDown(bitmap.dispose);
    final document = _Document(pageCount: 3, bitmap: bitmap);
    final controller = PdfViewerController();
    await tester.pumpWidget(MaterialApp(
        home: PdfViewer(
      PdfDocumentRefDirect(document),
      controller: controller,
      params: const PdfViewerParams(
          enableTextSelection: false,
          horizontalCacheExtent: 0,
          verticalCacheExtent: 0,
          onePassRenderingScaleThreshold: 1,
          maxImageBytesCachedOnMemory: 32 * 1024 * 1024),
    )));
    await tester.pumpAndSettle();
    final firstPage = document.pages.first as _Page;
    final before = firstPage.baseRenderCount;
    expect(before, greaterThan(0));
    await controller.goToPage(pageNumber: 2, duration: Duration.zero);
    await tester.pumpAndSettle();
    await controller.goToPage(pageNumber: 1, duration: Duration.zero);
    await tester.pumpAndSettle();
    expect(firstPage.baseRenderCount, before);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('deferred zoom rendering uses the current viewport scale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final document = _Document();
    final controller = PdfViewerController();
    await tester.pumpWidget(MaterialApp(
        home: PdfViewer(
      PdfDocumentRefDirect(document),
      controller: controller,
      params: const PdfViewerParams(
          enableTextSelection: false,
          onePassRenderingScaleThreshold: 1,
          minScale: .1,
          maxScale: 6),
    )));
    await tester.pumpAndSettle();
    expect(controller.isReady, isTrue);
    controller.value =
        controller.calcMatrixFor(const Offset(300, 420), zoom: 6);
    await tester.pump(const Duration(milliseconds: 10));
    // Change the matrix before the queued 50 ms render executes, without first
    // painting a replacement request. This recreates the stale-scale window.
    controller.value =
        controller.calcMatrixFor(const Offset(300, 420), zoom: 2);
    await tester.pump(const Duration(milliseconds: 60));
    final partials = (document.pages.first as _Page).renders;
    expect(partials, isNotEmpty);
    for (final size in partials) {
      expect(size.width, lessThanOrEqualTo(400));
      expect(size.height, lessThanOrEqualTo(600));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
