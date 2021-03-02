import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';

import 'package:path/path.dart';

class CameraPreviewScreen extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<CameraPreviewScreen> with TickerProviderStateMixin {
  CameraController controller;
  List cameras;
  int selectedCameraIdx;

  XFile capturedFile;
  bool isPreView = false;
  bool isPrecessing = false;

  Future _initCameraController(CameraDescription cameraDescription) async {
    setState(() {
      isPrecessing = true;
    });
    if (controller != null) {
      await controller.dispose();
    }

    controller = CameraController(cameraDescription, ResolutionPreset.high);

    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }

      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {
        isPrecessing = false;
      });
    }
  }

  Widget _cameraTogglesRowWidget(BuildContext ctx) {
    if (cameras == null || cameras.isEmpty) {
      return Spacer();
    }

    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    CameraLensDirection lensDirection = selectedCamera.lensDirection;

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FlatButton.icon(
            onPressed: isPrecessing
                ? null
                : () {
                    setState(() {
                      isPreView = false;
                    });
                    _onSwitchCamera();
                  },
            icon: Icon(
              _getCameraLensIcon(lensDirection),
              size: 35,
            ),
            label: Text(
                "${lensDirection.toString().substring(lensDirection.toString().indexOf('.') + 1)}"),
          ),
          FlatButton.icon(
            onPressed: isPrecessing
                ? null
                : () {
                    if (isPreView) {
                      setState(() {
                        isPreView = false;
                      });
                    } else {
                      setState(() {
                        _onCapturePressed(context);
                      });
                    }
                  },
            icon: Icon(
              Icons.save,
              size: 35,
            ),
            label: isPreView ? Text('Retake') : Text('Capture'),
          ),
        ],
      ),
    );
  }

  void _onSwitchCamera() async {
    selectedCameraIdx =
        selectedCameraIdx < cameras.length - 1 ? selectedCameraIdx + 1 : 0;
    CameraDescription selectedCamera = cameras[selectedCameraIdx];

    await _initCameraController(selectedCamera);
    setState(() {
      isPreView = false;
    });
  }

  void onSetFlashModeButtonPressed(FlashMode mode) {
    setFlashMode(mode).then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Flash mode set to ${mode.toString().split('.').last}');
    });
  }

  Future<void> setFlashMode(FlashMode mode) async {
    try {
      await controller.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use

    _scaffoldKey.currentState.hideCurrentSnackBar();
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  IconData _getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
      default:
        return Icons.device_unknown;
    }
  }

  void _onCapturePressed(context) async {
    setState(() {
      isPrecessing = true;
    });
    try {
      capturedFile = await controller.takePicture();

      setState(() {
        isPrecessing = false;
        isPreView = true;
      });
    } catch (e) {
      print(e);
    }
  }

  Widget _imagePreviewOrCamera() {
    if (isPrecessing) {
      return Expanded(
          flex: 1, child: Center(child: CircularProgressIndicator()));
    }
    if (isPreView) {
      return Expanded(
        flex: 1,
        child: Stack(
          children: [
            Container(
              child: Image.file(File(capturedFile.path)),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.only(top: 25),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.rectangle,
                ),
                child: IconButton(
                    iconSize: 40,
                    icon: Icon(
                      Icons.share,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      getBytesFromFile().then((bytes) {
                        Share.file('Share via:', basename(capturedFile.path),
                            bytes.buffer.asUint8List(), 'image/png');
                      });
                    }),
              ),
            )
          ],
        ),
      );
    } else {
      return Expanded(
        flex: 1,
        child: Container(
          child: Stack(
            children: [
              _cameraPreviewWidget(),
              Container(
                padding: EdgeInsets.all(10),
                color: Colors.black.withOpacity(0.2),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 30,
                      icon: Icon(
                        Icons.flash_off,
                      ),
                      color: controller?.value?.flashMode == FlashMode.off
                          ? Colors.orange
                          : Colors.blue,
                      onPressed: controller != null
                          ? () => onSetFlashModeButtonPressed(FlashMode.off)
                          : null,
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: Icon(Icons.flash_auto),
                      color: controller?.value?.flashMode == FlashMode.auto
                          ? Colors.orange
                          : Colors.blue,
                      onPressed: controller != null
                          ? () => onSetFlashModeButtonPressed(FlashMode.auto)
                          : null,
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: Icon(Icons.flash_on),
                      color: controller?.value?.flashMode == FlashMode.always
                          ? Colors.orange
                          : Colors.blue,
                      onPressed: controller != null
                          ? () => onSetFlashModeButtonPressed(FlashMode.always)
                          : null,
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: Icon(Icons.highlight),
                      color: controller?.value?.flashMode == FlashMode.torch
                          ? Colors.orange
                          : Colors.blue,
                      onPressed: controller != null
                          ? () => onSetFlashModeButtonPressed(FlashMode.torch)
                          : null,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Loading',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.0,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return CameraPreview(controller);
  }

  Future<ByteData> getBytesFromFile() async {
    Uint8List bytes = File(capturedFile.path).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  @override
  void dispose() {
    super.dispose();
    if (controller != null) {
      controller.dispose();
    }
  }

  @override
  void initState() {
    super.initState();

    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        setState(() {
          selectedCameraIdx = 0;
        });

        _initCameraController(cameras[selectedCameraIdx]).then((void v) {});
      } else {
        print("No camera available");
      }
    }).catchError((err) {
      print('Error: $err.code\nError Message: $err.message');
    });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Click Photo'),
      ),
      body: Container(
        child: Column(
          children: [_imagePreviewOrCamera(), _cameraTogglesRowWidget(context)],
        ),
      ),
    );
  }
}
