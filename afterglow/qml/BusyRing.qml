import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property color color: "white"
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.visible }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - 2; radiusY: radiusX; startAngle: 0; sweepAngle: 100 }
        }
    }
}
