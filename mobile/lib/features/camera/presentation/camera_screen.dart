import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.auto;
  bool _permissionDenied = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && !_permissionDenied) {
      _initializeCamera();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initializeCamera();
    } else if (mounted) {
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _permissionDenied = !status.isGranted);
    if (status.isGranted) await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _cameraIndex = _cameraIndex.clamp(0, _cameras.length - 1);
      final old = _controller;
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await old?.dispose();
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) setState(() {});
    } on CameraException {
      if (mounted) setState(() => _permissionDenied = true);
    } finally {
      _initializing = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    final file = await controller.takePicture();
    if (!mounted) return;
    context.push(
      Uri(
        path: '/preview',
        queryParameters: {'imagePath': file.path},
      ).toString(),
    );
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    context.push(
      Uri(
        path: '/preview',
        queryParameters: {'imagePath': file.path},
      ).toString(),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  Future<void> _cycleFlash() async {
    _flashMode = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    await _controller?.setFlashMode(_flashMode);
    if (mounted) setState(() {});
  }

  Future<void> _focus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final point = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0, 1),
      (details.localPosition.dy / constraints.maxHeight).clamp(0, 1),
    );
    await _controller?.setFocusPoint(point);
    await _controller?.setExposurePoint(point);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    return AppPage(
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Khoảnh khắc mới',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Semantics(
                label: 'Đổi chế độ đèn flash',
                button: true,
                child: IconButton(
                  onPressed: initialized ? _cycleFlash : null,
                  icon: Icon(switch (_flashMode) {
                    FlashMode.always => Icons.flash_on_rounded,
                    FlashMode.off => Icons.flash_off_rounded,
                    _ => Icons.flash_auto_rounded,
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: ColoredBox(
                color: AppColors.ink,
                child: _permissionDenied
                    ? _PermissionExplainer(onAllow: _requestPermission)
                    : !initialized
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          onTapDown: (details) => _focus(details, constraints),
                          child: SizedBox.expand(
                            child: CameraPreview(controller!),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CameraAction(
                label: 'Chọn từ thư viện',
                icon: Icons.photo_library_outlined,
                onTap: _pickImage,
              ),
              Semantics(
                label: 'Chụp ảnh',
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: initialized ? _capture : null,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppColors.orange, width: 7),
                    ),
                  ),
                ),
              ),
              _CameraAction(
                label: 'Lật camera',
                icon: Icons.cameraswitch_outlined,
                onTap: _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionExplainer extends StatelessWidget {
  const _PermissionExplainer({required this.onAllow});
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Cho phép camera để chụp khoảnh khắc. Ảnh chỉ được đăng sau khi khuôn mặt đã được xử lý.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onAllow,
            child: const Text('Cho phép camera'),
          ),
        ],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 25,
    ),
  );
}
