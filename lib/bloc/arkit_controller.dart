import 'dart:async';
import 'dart:typed_data';

import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:arkit_plugin/arkit_video_node.dart';
import 'package:arkit_plugin/bloc/arkit_arplane_detection.dart';
import 'package:arkit_plugin/bloc/arkit_configuration.dart';
import 'package:arkit_plugin/bloc/arkit_world_alignment.dart';
import 'package:arkit_plugin/geometries/arkit_anchor.dart';
import 'package:arkit_plugin/geometries/arkit_box.dart';
import 'package:arkit_plugin/geometries/arkit_capsule.dart';
import 'package:arkit_plugin/geometries/arkit_cone.dart';
import 'package:arkit_plugin/geometries/arkit_cylinder.dart';
import 'package:arkit_plugin/geometries/arkit_plane.dart';
import 'package:arkit_plugin/geometries/arkit_pyramid.dart';
import 'package:arkit_plugin/geometries/arkit_sphere.dart';
import 'package:arkit_plugin/geometries/arkit_text.dart';
import 'package:arkit_plugin/geometries/arkit_torus.dart';
import 'package:arkit_plugin/geometries/arkit_tube.dart';
import 'package:arkit_plugin/hit/arkit_hit_test_result.dart';
import 'package:arkit_plugin/hit/arkit_node_pan_result.dart';
import 'package:arkit_plugin/hit/arkit_node_pinch_result.dart';
import 'package:arkit_plugin/light/arkit_light_estimate.dart';
import 'package:arkit_plugin/utils/matrix4_utils.dart';
import 'package:arkit_plugin/utils/vector_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

typedef ARKitPluginCreatedCallback = void Function(ARKitController controller);
typedef StringResultHandler = void Function(String text);
typedef AnchorEventHandler = void Function(ARKitAnchor anchor);
typedef ARKitHitResultHandler = void Function(List<ARKitTestResult> hits);
typedef ARKitPanResultHandler = void Function(List<ARKitNodePanResult> pans);
typedef ARKitPinchGestureHandler = void Function(
    List<ARKitNodePinchResult> pinch);

/// Controls an [ARKitSceneView].
///
/// An [ARKitController] instance can be obtained by setting the [ARKitSceneView.onARKitViewCreated]
/// callback for an [ARKitSceneView] widget.
class ARKitController {
  // ARKitController._init(
  //   int id,
  //   ARKitConfiguration configuration,
  //   bool showStatistics,
  //   bool autoenablesDefaultLighting,
  //   bool enableTapRecognizer,
  //   bool showFeaturePoints,
  //   bool showWorldOrigin,
  //   bool enablePinchRecognizer,
  //   bool enablePanRecognizer,
  //   ARPlaneDetection planeDetection,
  //   ARWorldAlignment worldAlignment,
  //   String detectionImagesGroupName,
  //   String trackingImagesGroupName,
  //   bool forceUserTapOnCenter,
  //   this.debug,
  // ) {
  //   _channel = MethodChannel('arkit');
  //   _channel.setMethodCallHandler(_platformCallHandler);
  //   _channel.invokeMethod<void>('init', {
  //     'configuration': configuration.index,
  //     'showStatistics': showStatistics,
  //     'autoenablesDefaultLighting': autoenablesDefaultLighting,
  //     'enableTapRecognizer': enableTapRecognizer,
  //     'enablePinchRecognizer': enablePinchRecognizer,
  //     'enablePanRecognizer': enablePanRecognizer,
  //     'planeDetection': planeDetection.index,
  //     'showFeaturePoints': showFeaturePoints,
  //     'showWorldOrigin': showWorldOrigin,
  //     'detectionImagesGroupName': detectionImagesGroupName,
  //     'trackingImagesGroupName': trackingImagesGroupName,
  //     'forceUserTapOnCenter': forceUserTapOnCenter,
  //     'worldAlignment': worldAlignment.index,
  //   });
  // }

  static Future<bool>
      isARKitWorldTrackingSessionConfigurationSupported() async {
    var channel = MethodChannel('prepare_arkit');
    return await channel
        .invokeMethod('isARKitWorldTrackingSessionConfigurationSupported');
  }

  ///
  /// Dynamic loading ARKitImageAnchor
  ///
  ARKitController.initStartWorldTrackingSessionWithImage(
    int id,
    ARKitConfiguration configuration,
    bool showStatistics,
    bool autoenablesDefaultLighting,
    bool enableTapRecognizer,
    bool showFeaturePoints,
    bool showWorldOrigin,
    bool enablePinchRecognizer,
    bool enablePanRecognizer,
    ARPlaneDetection planeDetection,
    ARWorldAlignment worldAlignment,
    bool forceUserTapOnCenter,
    bool lightEstimationEnabled,
    bool autoFocusEnabled,
    int maximumNumberOfTrackedImages,
    this.debug,
  ) {
    _channel = MethodChannel('arkit');
    _channel.setMethodCallHandler(_platformCallHandler);
    _channel.invokeMethod<void>('initStartWorldTrackingSessionWithImage', {
      'configuration': configuration.index,
      'showStatistics': showStatistics,
      'autoenablesDefaultLighting': autoenablesDefaultLighting,
      'enableTapRecognizer': enableTapRecognizer,
      'enablePinchRecognizer': enablePinchRecognizer,
      'enablePanRecognizer': enablePanRecognizer,
      'planeDetection': planeDetection.index,
      'showFeaturePoints': showFeaturePoints,
      'showWorldOrigin': showWorldOrigin,
      'forceUserTapOnCenter': forceUserTapOnCenter,
      'worldAlignment': worldAlignment.index,
      'lightEstimationEnabled': lightEstimationEnabled,
      'autoFocusEnabled': autoFocusEnabled,
      'maximumNumberOfTrackedImages': maximumNumberOfTrackedImages,
    });
  }

  void addImageRunWithConfigAndImage(Uint8List bytes, int lengthInBytes,
      String imageName, double markerSizeMeter) {
    _channel.invokeMethod<void>('addImageRunWithConfigAndImage', {
      'imageBytes': bytes,
      'imageLength': lengthInBytes,
      'imageName': imageName,
      'markerSizeMeter': markerSizeMeter,
    });
  }

  void startWorldTrackingSessionWithImage(int runOptions) {
    _channel.invokeMethod<void>('startWorldTrackingSessionWithImage', {
      'runOptions': runOptions,
    });
  }

  MethodChannel _channel;

  /// This is called when a session fails.
  /// On failure the session will be paused.
  StringResultHandler onError;

  /// This is called when a session is interrupted.
  /// A session will be interrupted and no longer able to track when
  /// it fails to receive required sensor data. This happens when video capture is interrupted,
  /// for example when the application is sent to the background or when there are
  /// multiple foreground applications (see AVCaptureSessionInterruptionReason).
  /// No additional frame updates will be delivered until the interruption has ended.
  VoidCallback onSessionWasInterrupted;

  /// This is called when a session interruption has ended.
  /// A session will continue running from the last known state once
  /// the interruption has ended. If the device has moved, anchors will be misaligned.
  VoidCallback onSessionInterruptionEnded;

  StringResultHandler onNodeTap;
  ARKitHitResultHandler onPlaneTap;
  ARKitPinchGestureHandler onNodePinch;
  ARKitPanResultHandler onNodePan;
  Function(bool) onNurieMarkerModeChanged;
  Function(bool) onRecStatusChanged;

  /// Called when a new node has been mapped to the given anchor.
  AnchorEventHandler onAddNodeForAnchor;

  /// Called when a node will be updated with data from the given anchor.
  AnchorEventHandler onUpdateNodeForAnchor;

  static const int ANIMATION_REPEAT_INFINITE = -1;

  final bool debug;

  void dispose() {
    _channel?.invokeMethod<void>('dispose');
  }

  Future<void> add(ARKitNode node, {String parentNodeName}) {
    assert(node != null);
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    _subsribeToChanges(node);
    return _channel.invokeMethod('addARKitNode', params);
  }

  Future<void> remove(String nodeName) {
    assert(nodeName != null);
    return _channel.invokeMethod('removeARKitNode', {'nodeName': nodeName});
  }

  /// Return list of 2 Vector3 elements, where first element - min value, last element - max value.
  Future<List<Vector3>> getNodeBoundingBox(ARKitNode node) async {
    final params = _addParentNodeNameToParams(node.toMap(), null);
    final List<String> result =
        await _channel.invokeListMethod<String>('getNodeBoundingBox', params);
    return result
        .map((String value) => createVector3FromString(value))
        .toList();
  }

  Future<ARKitLightEstimate> getLightEstimate() async {
    final estimate =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getLightEstimate');
    return estimate != null
        ? ARKitLightEstimate.fromMap(estimate.cast<String, double>())
        : null;
  }

  /// Updates the geometry with the vertices of a face geometry.
  void updateFaceGeometry(ARKitNode node, String fromAnchorId) {
    _channel.invokeMethod<void>(
        'updateFaceGeometry',
        _getHandlerParams(
            node, <String, dynamic>{'fromAnchorId': fromAnchorId}));
  }

  Future<Vector3> projectPoint(Vector3 point) async {
    final projectPoint = await _channel.invokeMethod<String>(
        'projectPoint', {'point': convertVector3ToMap(point)});
    return projectPoint != null ? createVector3FromString(projectPoint) : null;
  }

  Future<Matrix4> cameraProjectionMatrix() async {
    final cameraProjectionMatrix =
        await _channel.invokeMethod<String>('cameraProjectionMatrix');
    return cameraProjectionMatrix != null
        ? getMatrixFromString(cameraProjectionMatrix)
        : null;
  }

  Future<void> startAnimation(
    String nodeName, {
    @required String key,
    @required String sceneName,
    @required String animationIdentifier,
    int repeatCount = 0,
  }) {
    assert(key != null);
    assert(sceneName != null);
    assert(animationIdentifier != null);

    return _channel.invokeMethod('startAnimation', {
      'nodeName': nodeName,
      'key': key,
      'sceneName': sceneName,
      'animationIdentifier': animationIdentifier,
      'repeatCount': repeatCount,
    });
  }

  Future<void> stopAnimation(
    String nodeName, {
    @required String key,
  }) {
    assert(key != null);

    return _channel.invokeMethod('stopAnimation', {
      'nodeName': nodeName,
      'key': key,
    });
  }

  void screenCapture() {
    _channel.invokeMethod<bool>('screenCapture');
  }

  Future<bool> toggleScreenRecord(
    String path, {
    ARKitRecordingWithAudio useAudio = ARKitRecordingWithAudio.None,
  }) {
    return _channel.invokeMethod<bool>(
        'toggleScreenRecord', {'path': path, 'useAudio': useAudio._value});
  }

  void startScreenRecord(
    String path, {
    ARKitRecordingWithAudio useAudio = ARKitRecordingWithAudio.None,
  }) {
    _channel.invokeMethod<void>(
        'startScreenRecord', {'path': path, 'useAudio': useAudio._value});
  }

  void stopScreenRecord() {
    _channel.invokeMethod<void>('stopScreenRecord');
  }

  void addNurie(
    String imageName,
    double markerSizeMeter, {
    int lengthInBytes,
    Uint8List bytes,
    String filePath,
    Vector2 scale,
    Vector2 offset,
  }) {
    bool paramsSatisfied = false;
    Map map = {
      'imageName': imageName,
      'markerSizeMeter': markerSizeMeter,
    };
    if (lengthInBytes != null && imageName != null) {
      map['imageLength'] = lengthInBytes;
      map['imageBytes'] = bytes;
      paramsSatisfied = true;
    }
    if (filePath != null) {
      map['filePath'] = filePath;
      paramsSatisfied = true;
    }
    if (scale != null) {
      map['widthScale'] = scale.x;
      map['heightScale'] = scale.y;
    }
    if (offset != null) {
      map['xOffset'] = offset.x;
      map['yOffset'] = offset.y;
    }

    if (paramsSatisfied) {
      _channel.invokeMethod<void>('addNurie', map);
    }
  }

  void findNurieMarker(
    bool isStart, {
    String nurie,
  }) {
    _channel.invokeMethod<void>(
        'findNurieMarker', {'isStart': isStart, 'nurie': nurie});
  }

  void applyNurieTexture(String nodeName, String nurie) {
    _channel.invokeMethod<void>(
        'applyNurieTexture', {'nurie': nurie, 'nodeName': nodeName});
  }

  // need to call in onPlaneTap
  void addTransformableNode(String transformName, ARKitNode node) {
    final Map map = node.toMap();
    map['parentNodeName'] = transformName;
    _channel.invokeMethod<void>(
        'addTransformableNode', {'transformName': transformName, 'node': map});
  }

  void addReferenceObject(String path, {String name}) {
    final Map<String, String> map = {'path': path};
    if (name != null) {
      map['name'] = name;
    }
    _channel.invokeMethod<void>('addReferenceObject', map);
  }

  Map<String, dynamic> _addParentNodeNameToParams(
      Map geometryMap, String parentNodeName) {
    if (parentNodeName?.isNotEmpty ?? false)
      geometryMap['parentNodeName'] = parentNodeName;
    return geometryMap;
  }

  Future<void> _platformCallHandler(MethodCall call) {
//    if (debug) {
    if (call.method != 'didUpdateNodeForAnchor') {
      print('_platformCallHandler call ${call.method} ${call.arguments}');
    }
//    }
    switch (call.method) {
      case 'onError':
        if (onError != null) {
          onError(call.arguments);
        }
        break;
      case 'onNodeTap':
        if (onNodeTap != null) {
          onNodeTap(call.arguments);
        }
        break;
      case 'onPlaneTap':
        if (onPlaneTap != null) {
          final List<dynamic> input = call.arguments;
          final objects = input
              .cast<Map<dynamic, dynamic>>()
              .map<ARKitTestResult>(
                  (Map<dynamic, dynamic> r) => ARKitTestResult.fromMap(r))
              .toList();
          onPlaneTap(objects);
        }
        break;
      case 'onNodePinch':
        if (onNodePinch != null) {
          final List<dynamic> input = call.arguments;
          final objects = input
              .cast<Map<dynamic, dynamic>>()
              .map<ARKitNodePinchResult>(
                  (Map<dynamic, dynamic> r) => ARKitNodePinchResult.fromMap(r))
              .toList();
          onNodePinch(objects);
        }
        break;
      case 'onNodePan':
        if (onNodePan != null) {
          final List<dynamic> input = call.arguments;
          final objects = input
              .cast<Map<dynamic, dynamic>>()
              .map<ARKitNodePanResult>(
                  (Map<dynamic, dynamic> r) => ARKitNodePanResult.fromMap(r))
              .toList();
          onNodePan(objects);
        }
        break;
      case 'didAddNodeForAnchor':
        print('**** didAddNodeForAnchor ${call.arguments}');
        if (onAddNodeForAnchor != null) {
          final anchor = _buildAnchor(call.arguments);
          onAddNodeForAnchor(anchor);
        }
        break;
      case 'didUpdateNodeForAnchor':
        if (onUpdateNodeForAnchor != null) {
          final anchor = _buildAnchor(call.arguments);
          onUpdateNodeForAnchor(anchor);
        }
        break;
      case 'nurieMarkerModeChanged':
        if (onNurieMarkerModeChanged != null) {
          onNurieMarkerModeChanged(call.arguments['isStart']);
        }
        break;
      case 'onRecStatusChanged':
        if (onRecStatusChanged != null) {
          onRecStatusChanged(call.arguments['isRecording']);
        }
        break;
      default:
        if (debug) {
          print('Unknowm method ${call.method} ');
        }
    }
    return Future.value();
  }

  void _subsribeToChanges(ARKitNode node) {
    node.position.addListener(() => _handlePositionChanged(node));
    node.rotation.addListener(() => _handleRotationChanged(node));
    node.eulerAngles.addListener(() => _handleEulerAnglesChanged(node));
    node.scale.addListener(() => _handleScaleChanged(node));

    node.isHidden.addListener(() => _handleIsHiddenChanged(node));

    if (node is ARKitVideoNode) {
      node.isPlay.addListener(() => _handleIsPlayChanged(node));
    }

    if (node.geometry != null) {
      node.geometry.materials.addListener(() => _updateMaterials(node));
      switch (node.geometry.runtimeType) {
        case ARKitPlane:
          _subscribeToPlaneGeometry(node);
          break;
        case ARKitSphere:
          _subscribeToSphereGeometry(node);
          break;
        case ARKitText:
          _subscribeToTextGeometry(node);
          break;
        case ARKitBox:
          _subscribeToBoxGeometry(node);
          break;
        case ARKitCylinder:
          _subscribeToCylinderGeometry(node);
          break;
        case ARKitCone:
          _subscribeToConeGeometry(node);
          break;
        case ARKitPyramid:
          _subscribeToPyramidGeometry(node);
          break;
        case ARKitTube:
          _subscribeToTubeGeometry(node);
          break;
        case ARKitTorus:
          _subscribeToTorusGeometry(node);
          break;
        case ARKitCapsule:
          _subscribeToCapsuleGeometry(node);
          break;
      }
    }
    if (node.light != null) {
      node.light.intensity.addListener(() => _updateSingleProperty(
          node, 'intensity', node.light.intensity.value, 'light'));
    }
  }

  void _subscribeToCapsuleGeometry(ARKitNode node) {
    final ARKitCapsule capsule = node.geometry;
    capsule.capRadius.addListener(() => _updateSingleProperty(
        node, 'capRadius', capsule.capRadius.value, 'geometry'));
    capsule.height.addListener(() => _updateSingleProperty(
        node, 'height', capsule.height.value, 'geometry'));
  }

  void _subscribeToTorusGeometry(ARKitNode node) {
    final ARKitTorus torus = node.geometry;
    torus.pipeRadius.addListener(() => _updateSingleProperty(
        node, 'pipeRadius', torus.pipeRadius.value, 'geometry'));
    torus.ringRadius.addListener(() => _updateSingleProperty(
        node, 'ringRadius', torus.ringRadius.value, 'geometry'));
  }

  void _subscribeToTubeGeometry(ARKitNode node) {
    final ARKitTube tube = node.geometry;
    tube.innerRadius.addListener(() => _updateSingleProperty(
        node, 'innerRadius', tube.innerRadius.value, 'geometry'));
    tube.outerRadius.addListener(() => _updateSingleProperty(
        node, 'outerRadius', tube.outerRadius.value, 'geometry'));
    tube.height.addListener(() =>
        _updateSingleProperty(node, 'height', tube.height.value, 'geometry'));
  }

  void _subscribeToPyramidGeometry(ARKitNode node) {
    final ARKitPyramid pyramid = node.geometry;
    pyramid.width.addListener(() =>
        _updateSingleProperty(node, 'width', pyramid.width.value, 'geometry'));
    pyramid.height.addListener(() => _updateSingleProperty(
        node, 'height', pyramid.height.value, 'geometry'));
    pyramid.length.addListener(() => _updateSingleProperty(
        node, 'length', pyramid.length.value, 'geometry'));
  }

  void _subscribeToConeGeometry(ARKitNode node) {
    final ARKitCone cone = node.geometry;
    cone.topRadius.addListener(() => _updateSingleProperty(
        node, 'topRadius', cone.topRadius.value, 'geometry'));
    cone.bottomRadius.addListener(() => _updateSingleProperty(
        node, 'bottomRadius', cone.bottomRadius.value, 'geometry'));
    cone.height.addListener(() =>
        _updateSingleProperty(node, 'height', cone.height.value, 'geometry'));
  }

  void _subscribeToCylinderGeometry(ARKitNode node) {
    final ARKitCylinder cylinder = node.geometry;
    cylinder.radius.addListener(() => _updateSingleProperty(
        node, 'radius', cylinder.radius.value, 'geometry'));
    cylinder.height.addListener(() => _updateSingleProperty(
        node, 'height', cylinder.height.value, 'geometry'));
  }

  void _subscribeToBoxGeometry(ARKitNode node) {
    final ARKitBox box = node.geometry;
    box.width.addListener(() =>
        _updateSingleProperty(node, 'width', box.width.value, 'geometry'));
    box.height.addListener(() =>
        _updateSingleProperty(node, 'height', box.height.value, 'geometry'));
    box.length.addListener(() =>
        _updateSingleProperty(node, 'length', box.length.value, 'geometry'));
  }

  void _subscribeToTextGeometry(ARKitNode node) {
    final ARKitText text = node.geometry;
    text.text.addListener(
        () => _updateSingleProperty(node, 'text', text.text.value, 'geometry'));
  }

  void _subscribeToSphereGeometry(ARKitNode node) {
    final ARKitSphere sphere = node.geometry;
    sphere.radius.addListener(() =>
        _updateSingleProperty(node, 'radius', sphere.radius.value, 'geometry'));
  }

  void _subscribeToPlaneGeometry(ARKitNode node) {
    final ARKitPlane plane = node.geometry;
    plane.width.addListener(() =>
        _updateSingleProperty(node, 'width', plane.width.value, 'geometry'));
    plane.height.addListener(() =>
        _updateSingleProperty(node, 'height', plane.height.value, 'geometry'));
  }

  void _handlePositionChanged(ARKitNode node) {
    _channel.invokeMethod<void>('positionChanged',
        _getHandlerParams(node, convertVector3ToMap(node.position.value)));
  }

  void _handleRotationChanged(ARKitNode node) {
    _channel.invokeMethod<void>('rotationChanged',
        _getHandlerParams(node, convertVector4ToMap(node.rotation.value)));
  }

  void _handleEulerAnglesChanged(ARKitNode node) {
    _channel.invokeMethod<void>('eulerAnglesChanged',
        _getHandlerParams(node, convertVector3ToMap(node.eulerAngles.value)));
  }

  void _handleScaleChanged(ARKitNode node) {
    _channel.invokeMethod<void>('scaleChanged',
        _getHandlerParams(node, convertVector3ToMap(node.scale.value)));
  }

  void _handleIsHiddenChanged(ARKitNode node) {
    _channel.invokeMethod<void>('isHiddenChanged',
        _getHandlerParams(node, {'isHidden': node.isHidden.value}));
  }

  void _handleIsPlayChanged(ARKitVideoNode node) {
    _channel.invokeMethod<void>('isPlayChanged',
        _getHandlerParams(node, {'isPlay': node.isPlay.value}));
  }

  void _updateMaterials(ARKitNode node) {
    _channel.invokeMethod<void>(
        'updateMaterials', _getHandlerParams(node, node.geometry.toMap()));
  }

  void _updateSingleProperty(
      ARKitNode node, String propertyName, dynamic value, String keyProperty) {
    _channel.invokeMethod<void>(
        'updateSingleProperty',
        _getHandlerParams(node, <String, dynamic>{
          'propertyName': propertyName,
          'propertyValue': value,
          'keyProperty': keyProperty,
        }));
  }

  Map<String, dynamic> _getHandlerParams(
      ARKitNode node, Map<String, dynamic> params) {
    final Map<String, dynamic> values = <String, dynamic>{'name': node.name}
      ..addAll(params);
    return values;
  }

  ARKitAnchor _buildAnchor(Map arguments) {
    final type = arguments['anchorType'].toString();
    final map = arguments.cast<String, String>();
    switch (type) {
      case 'planeAnchor':
        return ARKitPlaneAnchor.fromMap(map);
      case 'imageAnchor':
        return ARKitImageAnchor.fromMap(map);
      case 'faceAnchor':
        return ARKitFaceAnchor.fromMap(map);
      case 'objectAnchor':
        return ARKitObjectAnchor.fromMap(map);
    }
    return ARKitAnchor.fromMap(map);
  }
}

class ARKitRecordingWithAudio {
  const ARKitRecordingWithAudio._(this._value, this._text);

  static const ARKitRecordingWithAudio None =
      ARKitRecordingWithAudio._(0, 'None');
  static const ARKitRecordingWithAudio UseMic =
      ARKitRecordingWithAudio._(1, 'UseMic');
  static final values = [
    None,
    UseMic,
  ];

  final int _value;
  final String _text;

  static ARKitRecordingWithAudio get(int value) {
    ARKitRecordingWithAudio ret = UseMic;
    values.forEach((m) {
      if (m._value == value) {
        ret = m;
        return;
      }
    });
    return ret;
  }

  @override
  String toString() {
    return '$_text - $_value';
  }
}
