

import Foundation
#if IOS
import UIKit

extension CGAffineTransform {
    var xScale: CGFloat { return sqrt(self.a * self.a + self.c * self.c) }
    var yScale: CGFloat { return sqrt(self.b * self.b + self.d * self.d) }
    var rotation: CGFloat { return CGFloat(atan2(Double(self.b), Double(self.a))) }
}


public extension CALayer {
    public static let lockKey = "isLocked"
    
    public func setLockStatus(_ isLocked: Bool) {
        setValue(isLocked, forKey: Self.lockKey)
    }
    
    public  func getLockStatus() -> Bool {
        return value(forKey: Self.lockKey) as? Bool ?? false
    }
}
extension CATransaction {
    class func withDisabledActions<T>(_ body: () throws -> T) rethrows -> T {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.commit()
        }
        return try body()
    }
}
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

extension String {
    /// Try to parse the string into NSNumber (like your `getNsNumber()` used to do).
    var asNSNumber: NSNumber? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if let double = Double(trimmed) { return NSNumber(value: double) }
        return nil
    }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0
        
        var rgbValue: UInt64 = 0
        
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }
    
    func rgb() -> Int? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = Int(fRed * 255.0)
            let iGreen = Int(fGreen * 255.0)
            let iBlue = Int(fBlue * 255.0)
            let iAlpha = Int(fAlpha * 255.0)
            
            //  (Bits 24-31 are alpha, 16-23 are red, 8-15 are green, 0-7 are blue).
            let rgb = (iAlpha << 24) + (iRed << 16) + (iGreen << 8) + iBlue
            return rgb
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
    
    convenience init(hexString:String) {
        let set = NSCharacterSet.whitespacesAndNewlines
        let hexString:NSString = hexString.trimmingCharacters(in: set) as NSString
        let scanner  = Scanner(string: hexString as String)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color:UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        
        self.init(red:red, green:green, blue:blue, alpha:1)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return NSString(format:"#%06x", rgb) as String
    }
}
#endif
