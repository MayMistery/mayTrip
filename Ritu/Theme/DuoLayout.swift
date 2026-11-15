import CoreGraphics
import SwiftUI

/// Where an active hinge splits the canvas. Frames are in the measuring view's coordinates.
struct FoldGuide: Equatable {
    enum Axis: Equatable {
        case vertical
        case horizontal
    }

    var axis: Axis
    var frame: CGRect

    /// Active division regions only. A flat iPhone Duo reports none, so the layout
    /// falls through to size class and available width.
    static func current(in proxy: GeometryProxy) -> FoldGuide? {
        guard #available(iOS 27.1, *) else { return nil }
        return currentOnDuo(in: proxy)
    }

    @available(iOS 27.1, *)
    private static func currentOnDuo(in proxy: GeometryProxy) -> FoldGuide? {
        let frames = proxy.reservedRegions(kind: .division).map(\.frame)
        guard let frame = frames.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        guard frame.width > 1 || frame.height > 1 else { return nil }
        let axis: Axis = frame.height >= frame.width ? .vertical : .horizontal
        return FoldGuide(axis: axis, frame: frame)
    }
}

/// Phone column, list beside map, or map above the list when the hinge is horizontal.
enum StageLayout: Equatable {
    case phone
    case columns(leading: CGFloat, separator: CGFloat, trailing: CGFloat)
    case stacked(top: CGFloat, separator: CGFloat, bottom: CGFloat)

    var isPhone: Bool {
        if case .phone = self { return true }
        return false
    }

    static func resolve(
        size: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass?,
        fold: FoldGuide?
    ) -> StageLayout {
        if let fold, fold.axis == .vertical {
            let leading = max(0, fold.frame.minX)
            let gap = max(0, fold.frame.width)
            let trailing = max(0, size.width - fold.frame.maxX)
            if leading >= 140, trailing >= 160, gap < size.width * 0.45 {
                return .columns(leading: leading, separator: gap, trailing: trailing)
            }
        }

        if let fold, fold.axis == .horizontal {
            let top = max(0, fold.frame.minY)
            let gap = max(0, fold.frame.height)
            let bottom = max(0, size.height - fold.frame.maxY)
            if top >= 140, bottom >= 180, gap < size.height * 0.45 {
                return .stacked(top: top, separator: gap, bottom: bottom)
            }
        }

        let regular = horizontalSizeClass == .regular
        let wideEnough = size.width >= (regular ? 560 : 640) && size.height >= 360
        guard wideEnough else { return .phone }

        let separator: CGFloat = 1
        let leading = min(380, max(280, floor(size.width * 0.38)))
        let trailing = size.width - leading - separator
        guard trailing >= 240 else { return .phone }
        return .columns(leading: leading, separator: separator, trailing: trailing)
    }
}
