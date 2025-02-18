import 'dart:math' as math;

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:arkit_plugin_example/broken_slide_rrect.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class CustomObjectPage extends StatefulWidget {
  @override
  _CustomObjectPageState createState() => _CustomObjectPageState();
}

class _CustomObjectPageState extends State<CustomObjectPage> {
  late ARKitController arkitController;
  ARKitReferenceNode? node;

  // ImageProvider? imageProvider;

  List<ImageProvider> imageList = [];
  final ScrollController _scrollController = ScrollController();

  bool isRecording = false;

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const imageWidth = 90.0;
    const imageHeight = 160.0;
    return Scaffold(
      // appBar: AppBar(title: const Text('Custom object on plane Sample')),
      body: Stack(
        children: [
          SizedBox(
            // height: 503,
            child: ARKitSceneView(
              showFeaturePoints: false,
              showWorldOrigin: false,
              enableTapRecognizer: true,
              enablePanRecognizer: true,
              enableRotationRecognizer: true,
              environmentTexturing: ARWorldTrackingConfigurationEnvironmentTexturing.automatic,
              planeDetection: ARPlaneDetection.horizontalAndVertical,
              onARKitViewCreated: onARKitViewCreated,
            ),
          ),

          // 中间显示一个中间是断开的圆角矩形
          Center(
            child: CustomPaint(
              size: const Size(55, 55),
              painter: BrokenSidesRRectPainter(
                radius: 8,
                strokeWidth: 4,
                color: Colors.white,
              ),
            ),
          ),

          SizedBox(
            height: imageHeight,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              scrollDirection: Axis.horizontal,
              itemCount: imageList.length,
              itemExtent: imageWidth,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Image(
                      image: imageList[index],
                      width: imageWidth,
                      height: imageHeight,
                    ),
                  ),
                );
              },
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: CircularBorderButton(() {
              isRecording = !isRecording;
              arkitController.setIsRecording(isRecording);
              setState(() {});
            }),
          ),
        ],
      ),
    );
  }

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    arkitController.addCoachingOverlay(CoachingOverlayGoal.horizontalPlane);
    // arkitController.onAddNodeForAnchor = _handleAddAnchor;
    arkitController.onCameraImageUpdate = (result) {
      debugPrint('onCameraImageUpdate');
      if (isRecording) {
        var imageData = result?['data'];
        var newImg = MemoryImage(imageData);
        // imageProvider = newImg;
        imageList.add(newImg);
        debugPrint('imageList.length: ${imageList.length}');
        setState(() {});

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
            );
          }
        });
      }
    };
    arkitController.onCameraDidChangeTrackingState = (state, reason) {
      debugPrint('onCameraDidChangeTrackingState did change tracking state: $state, $reason');
    };
  }

  void _handleAddAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitPlaneAnchor) {
      _addPlane(arkitController, anchor);
    }
  }

  void _addPlane(ARKitController controller, ARKitPlaneAnchor anchor) {
    if (node != null) {
      controller.remove(node!.name);
    }
    node = ARKitReferenceNode(
      url: 'models.scnassets/dash.dae',
      scale: vector.Vector3.all(0.3),
    );
    controller.add(node!, parentNodeName: anchor.nodeName);
  }
}

class CircularBorderButton extends StatefulWidget {
  VoidCallback onTap;

  CircularBorderButton(this.onTap, {Key? key}) : super(key: key);

  @override
  _CircularBorderButtonState createState() => _CircularBorderButtonState();
}

class _CircularBorderButtonState extends State<CircularBorderButton> {
  bool _clicked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        setState(() {
          _clicked = !_clicked;
        });
      },
      child: Container(
        // 外层容器：固定大小，形状是正圆，边框 2px
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 2,
            color: _clicked ? Colors.transparent : Colors.white,
          ),
          color: _clicked ? Colors.white30 : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeInOut,
              width: _clicked ? 25 : 70,
              height: _clicked ? 25 : 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_clicked ? 8 : 40),
                color: _clicked ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
