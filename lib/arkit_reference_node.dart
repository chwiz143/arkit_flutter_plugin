import 'package:arkit_plugin/arkit_node.dart';
import 'package:arkit_plugin/light/arkit_light.dart';
import 'package:arkit_plugin/physics/arkit_physics_body.dart';
import 'package:vector_math/vector_math_64.dart';

///  Node that references an external serialized node graph.
class ARKitReferenceNode extends ARKitNode {
  ARKitReferenceNode({
    this.object3DFileName,
    ARKitPhysicsBody physicsBody,
    ARKitLight light,
    Vector3 position,
    Vector3 scale,
    Vector3 eulerAngles,
    String name,
    int renderingOrder,
  }) : super(
          physicsBody: physicsBody,
          light: light,
          position: position,
          scale: scale,
          eulerAngles: eulerAngles,
          name: name,
          renderingOrder: renderingOrder,
        );

  /// Node url at bundle.
  final String object3DFileName;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'object3DFileName': object3DFileName,
      }..addAll(super.toMap());
}
