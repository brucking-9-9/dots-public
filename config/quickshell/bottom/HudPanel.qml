import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Angled-corner HUD background, GPU only (no Canvas): a Shape polygon fill,
// a stepped stroke along the top edge for the neon glow, and tiled 1 px
// scanlines. Cheap enough to animate height/width every frame.
Item {
    id: c
    property color fill: Theme.panel
    property color edge: Theme.cyan
    property int cut: Theme.cut
    property bool cutTL: true
    property bool cutTR: true
    property bool cutBL: false
    property bool cutBR: false
    property bool scanlines: true
    property real edgeWidth: 1.2
    property real glow: 1.0     // halo strength multiplier
    property bool soft: false   // halo = blurred copy of the edge (fades at the ends; costs a layer, keep off on animated-size panels)
    property real sides: 0.0    // 1 = the trim also runs down both sides to the bottom edge

    readonly property int k: Math.min(cut, Math.floor(Math.min(width, height) / 2))
    readonly property var outline: {
        const w = width, h = height, k = c.k;
        const p = [];
        p.push(Qt.point(cutTL ? k : 0, 0));
        p.push(Qt.point(cutTR ? w - k : w, 0));
        if (cutTR) p.push(Qt.point(w, k));
        p.push(Qt.point(w, cutBR ? h - k : h));
        if (cutBR) p.push(Qt.point(w - k, h));
        p.push(Qt.point(cutBL ? k : 0, h));
        if (cutBL) p.push(Qt.point(0, h - k));
        p.push(Qt.point(0, cutTL ? k : 0));
        p.push(Qt.point(cutTL ? k : 0, 0));
        return p;
    }
    readonly property var leftSide: [Qt.point(0, height), Qt.point(0, cutTL ? k : 0)]
    readonly property var rightSide: [Qt.point(width, cutTR ? k : 0), Qt.point(width, height)]
    readonly property var edgePath: {
        const w = width, k = c.k;
        const p = [];
        p.push(Qt.point(0, cutTL ? k : 0));
        if (cutTL) p.push(Qt.point(k, 0));
        p.push(Qt.point(cutTR ? w - k : w, 0));
        if (cutTR) p.push(Qt.point(w, k));
        return p;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: c.fill
            strokeColor: "transparent"
            PathPolyline { path: c.outline }
        }
    }

    // scanlines: full band below the cuts + a narrower band across the cut row
    Image {
        visible: c.scanlines
        x: 0; y: c.k; width: parent.width; height: Math.max(0, parent.height - c.k - (c.cutBL || c.cutBR ? c.k : 0))
        fillMode: Image.Tile
        source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAADCAYAAABS3WWCAAAAEklEQVR4nGP4//8/FwOQYAATAEg1CQJoX7/tAAAAAElFTkSuQmCC"
        smooth: false
    }
    Image {
        visible: c.scanlines
        x: c.cutTL ? c.k : 0; y: 0; width: parent.width - (c.cutTL ? c.k : 0) - (c.cutTR ? c.k : 0); height: c.k
        fillMode: Image.Tile
        source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAADCAYAAABS3WWCAAAAEklEQVR4nGP4//8/FwOQYAATAEg1CQJoX7/tAAAAAElFTkSuQmCC"
        smooth: false
    }

    Shape {   // side trim, connects the top edge to the screen's bottom border
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: c.sides
        visible: opacity > 0.01
        ShapePath {
            strokeColor: Qt.rgba(c.edge.r, c.edge.g, c.edge.b, 0.28 * c.glow)
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathPolyline { path: c.leftSide }
        }
        ShapePath {
            strokeColor: Qt.rgba(c.edge.r, c.edge.g, c.edge.b, 0.28 * c.glow)
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathPolyline { path: c.rightSide }
        }
        ShapePath {
            strokeColor: c.edge
            strokeWidth: c.edgeWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathPolyline { path: c.leftSide }
        }
        ShapePath {
            strokeColor: c.edge
            strokeWidth: c.edgeWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathPolyline { path: c.rightSide }
        }
    }

    Item {   // soft halo: the edge line blurred, so it tails off instead of ending flat
        visible: c.soft && c.glow > 0.01
        anchors.fill: parent
        anchors.margins: -28
        opacity: Math.min(1, 0.3 * c.glow)
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.8; blurMax: 20 }
        Shape {
            x: 28; y: 28; width: c.width; height: c.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: c.edge
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: c.edgePath }
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(c.edge.r, c.edge.g, c.edge.b, c.soft ? 0 : 0.10 * c.glow)
            strokeWidth: 12
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: c.edgePath }
        }
        ShapePath {
            strokeColor: Qt.rgba(c.edge.r, c.edge.g, c.edge.b, c.soft ? 0 : 0.28 * c.glow)
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: c.edgePath }
        }
        ShapePath {
            strokeColor: c.edge
            strokeWidth: c.edgeWidth
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: c.edgePath }
        }
    }
}
