//
//  File.swift
//  SVGEditor
//
//  Created by Apple on 22/12/2025.
//

import Foundation

extension CGRect {
    func scaleBy(_ scale: CGFloat) -> CGRect {
        return CGRect(origin: self.origin.scaleBy(scale), size: self.size.scaleBy(scale))
    }
    func center() -> CGPoint {
        return CGPoint(x: origin.x + (size.width/2), y: origin.y + (size.height/2))
    }
}
extension CGPoint {
    func scaleBy(_ scale: CGFloat) -> CGPoint {
        return CGPoint(x: self.x*scale, y: self.y*scale)
    }
}
extension CGSize {
    func scaleBy(_ scale: CGFloat) -> CGSize {
        return CGSize(width: self.width*scale, height: self.height*scale)
    }
}
enum LayerKeys {
    static let viewBox = "ViewBox"
    static let customX = "customX"
    static let customY = "customY"
    static let shadowColour = "shadowColour"
    static let underline = "underline"
    static let customRotate = "customRotate"
    static let extraX = "extraX"
    static let extraY = "extraY"
}
