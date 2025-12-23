// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SVGKit
#if IOS
import UIKit

protocol SVGEditorDelegate:AnyObject {
    func selectedSticker(layer:CALayer?)
    func updateStickerSize(layer: CALayer?)
    func updateStatus()
    func changeText()
}
public let shareUndoManager:UndoManager = UndoManager()
open class SVGEditor: UIView,UIGestureRecognizerDelegate {
    weak var delegate:SVGEditorDelegate!
    let TEXT_MAX_VALUE = CGFloat(500)
    let Shape_MAX_VALUE = CGFloat(500)
    let TEXT_MIN_VALUE = CGFloat(16)
    var gesture:UIPanGestureRecognizer?
    var tapGesture:UITapGestureRecognizer?
    var pinchGesture:UIPinchGestureRecognizer?
    var rotationResture:UIRotationGestureRecognizer?
    var missingFonts:[String] = [String]()
    var viewBoxSize:CGSize = .zero
    var layers:[CALayer] = [CALayer]()
    var containerView:UIView!
    var selectedVector: CALayer? = nil {
        didSet {
            layers.forEach({$0.borderWidth = 0})
            guard let selectedVector else {
                self.delegate.selectedSticker(layer: nil)
                return
            }
            if selectedVector.getLockStatus() || selectedVector.isHidden{
                return
            }
            selectedVector.borderColor = UIColor.black.cgColor
            selectedVector.borderWidth = 2
            self.delegate.selectedSticker(layer: selectedVector)
        }
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configUI()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configUI()
    }
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var tempLayer: CALayer? = nil
        var newPoint = self.convert(point, to: self.containerView)
        for layer in self.layers {
            newPoint = self.convert(point, to: self.containerView)
            let transform = layer.affineTransform()
            let angle = transform.rotation
            var layerFrame = layer.frame
            if angle != 0 {
                layer.setAffineTransform(transform.rotated(by: -angle))
                layerFrame = layer.frame
                layer.setAffineTransform(transform)
                var t:CGAffineTransform =  .identity
                let center = layerFrame.center()
                t = t.translatedBy(x: center.x, y: center.y)
                t = t.rotated(by: -angle)
                t = t.translatedBy(x: -center.x, y: -center.y)
                newPoint = newPoint.applying(t)
            }
            if !layer.isHidden && !layer.getLockStatus(){
                if layerFrame.contains(newPoint) {
                    tempLayer = layer
                }
            }
        }
        if tempLayer != nil{
            tapGesture?.isEnabled = true
            pinchGesture?.isEnabled = true
            rotationResture?.isEnabled = true
            gesture?.isEnabled = true
            selectedVector = tempLayer
        }else{
            tapGesture?.isEnabled = false
            pinchGesture?.isEnabled = false
            rotationResture?.isEnabled = false
            gesture?.isEnabled = false
            selectedVector = nil
        }
        if tempLayer != selectedVector {
            return nil
        }
        return self
    }
    func setContainerFrame(_ size:CGSize?) {
        var calculateRect = CGRect(origin: .zero, size: self.frame.size)
        if let size = size {
            let ratio = (self.frame.width / size.width)/(self.frame.height / size.height)
            if ratio > 1 {
                calculateRect = CGRect(x: 0, y: 0, width: frame.width/ratio, height: frame.height)
            }else if ratio < 1 {
                calculateRect = CGRect(x: 0, y: 0, width: frame.width, height: frame.height*ratio)
            }
            containerView.frame = calculateRect
            containerView.center = bounds.center()
        }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    func configUI() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(moveGesture(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestur))
        tap.numberOfTapsRequired = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchHandler(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotateVector(_:)))
        rotation.delaysTouchesBegan = false
        gesture = pan
        tapGesture = tap
        pinchGesture = pinch
        rotationResture = rotation
        // attach delegates and add recognizers
        [pan, tap, pinch, rotation].forEach {
            $0.delegate = self
            addGestureRecognizer($0)
        }
        // enable interaction and prepare containerView
        isUserInteractionEnabled = true
        // create containerView to cover full bounds and autoresize with superview
        let container = UIView(frame: bounds)
        container.backgroundColor = .clear
        container.clipsToBounds = true
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // replace any existing containerView if present
        containerView?.removeFromSuperview()
        containerView = container
        addSubview(container)
        clipsToBounds = true
    }
    func loadVectorFile(url:URL) {
        self.containerView.layer.sublayers?.removeAll()
        self.layers.removeAll()
        if let svgImg = SVGKImage(contentsOf: url){
            viewBoxSize = svgImg.size
            setContainerFrame(svgImg.size)
            svgImg.scaleToFit(inside:  self.containerView.frame.size)
            svgImg.size = self.containerView.frame.size
            let height = svgImg.size.height
            if height < 245 {
                setContainerFrame(CGSize(width: 800, height: 800))
                svgImg.caLayerTree.frame.origin = CGPoint(x: 0,y: containerView.frame.size.height / 2 - 100)
            }
            if let caLayerTree = svgImg.caLayerTree {
                self.containerView.layer.addSublayer(caLayerTree)
                loadAllLayer(caLayer: caLayerTree)
            }
        }
    }
    func loadAllLayer(caLayer: CALayer) {
        // If layer has sublayers: offset each sublayer by parent's origin and recurse.
        if let sublayers = caLayer.sublayers, !sublayers.isEmpty {
            // Remember parent's frame origin and zero it out (same intent as original code).
            let parentOrigin = caLayer.frame.origin
            caLayer.frame.origin = .zero
            
            for layer in sublayers {
                // preserve bounds (frame changes can alter bounds; original did this)
                let oldBounds = layer.bounds
                
                // shift child layer origin by parent origin (same as original logic)
                layer.frame.origin.x += parentOrigin.x
                layer.frame.origin.y += parentOrigin.y
                
                layer.bounds = oldBounds
                layer.backgroundColor = UIColor.clear.cgColor
                
                // recurse
                loadAllLayer(caLayer: layer)
            }
            
            return
        }
        
        // Leaf node handling (no sublayers)
        // Set viewBox key (keeps original behavior)
        caLayer.setValue(viewBoxSize, forKey: LayerKeys.viewBox)
        
        // If this layer is one of the types we care about, prepare it and append to layers.
        let isTargetType = caLayer is SVGTextLayer
        || caLayer is CAShapeLayerWithHitTest
        || caLayer is SVGGradientLayer
        || caLayer is CALayerWithClipRender
        
        guard isTargetType else { return }
        
        // Move anchor/position to center of frame
        let originalPosition = caLayer.position
        caLayer.position = CGPoint(x: caLayer.frame.midX, y: caLayer.frame.midY)
        caLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // If text layer, perform the extraX/extraY and customX/customY logic
        if caLayer is SVGTextLayer {
            let trans = caLayer.affineTransform()
            
            // compute extraX/extraY in original code: postion.x / trans.xScale etc.
            let extraX = originalPosition.x / trans.xScale
            let extraY = originalPosition.y / trans.yScale
            
            caLayer.setValue(extraX, forKey: LayerKeys.extraX)
            caLayer.setValue(extraY, forKey: LayerKeys.extraY)
            
            // base x,y using transforms and extras (following original math)
            var x = (trans.tx / trans.xScale) + extraX
            var y = (trans.ty / trans.yScale) + extraY
            
            // override with customX / customY if available and valid
            if let customX = caLayer.value(forKey: LayerKeys.customX) as? String,
               let n = customX.asNSNumber {
                x = CGFloat(truncating: n)
            }
            if let customY = caLayer.value(forKey: LayerKeys.customY) as? String,
               let n = customY.asNSNumber {
                y = CGFloat(truncating: n)
            }
            
            // shadow color (if present)
            if let shadowColorHex = caLayer.value(forKey: LayerKeys.shadowColour) as? String {
                caLayer.shadowColor = UIColor(hexString: shadowColorHex).cgColor
            }
            
            // apply computed frame origin scaled by transform's scale (keeps original behavior)
            caLayer.frame.origin = CGPoint(x: x * trans.xScale, y: y * trans.yScale)
            
            // underline handling (original checked presence as String)
        }
        // custom rotation (if provided as string degrees)
        if let rotat = caLayer.value(forKey: LayerKeys.customRotate) as? String,
           let doubleVal = Double(rotat), doubleVal != 0 {
            let angle = CGFloat(doubleVal) * .pi / 180
            caLayer.setAffineTransform(caLayer.affineTransform().rotated(by: angle))
        }
        
        // append to layers array as original did
        layers.append(caLayer)
    }
    @objc func moveGesture(_ gesture: UIPanGestureRecognizer) {
        CATransaction.withDisabledActions{[weak self] in
            guard let self ,let selectedVector else {return}
            if selectedVector.getLockStatus(){
                return
            }
            let translation = gesture.translation(in: self)
            let transForm = selectedVector.affineTransform()
            if gesture.state == .began {
                let transForm = selectedVector.affineTransform()
                selectedVector.setAffineTransform(.identity)
                let point = CGPoint(x: selectedVector.frame.origin.x+translation.x, y: selectedVector.frame.origin.y+translation.y)
                translate(layer: selectedVector, point: point,oldPoint: selectedVector.frame.origin,position: selectedVector.position)
                selectedVector.setAffineTransform(transForm)
            }else if gesture.state == .changed {
                selectedVector.setAffineTransform(.identity)
                selectedVector.frame.origin = CGPoint(x: selectedVector.frame.origin.x+translation.x, y: selectedVector.frame.origin.y+translation.y)
                selectedVector.setAffineTransform(transForm)
                gesture.setTranslation(.zero, in: self)
            }else if gesture.state == .ended {
                //print("gesture.state == .ended")
            }
        }
    }
    func translate(layer: CALayer,point: CGPoint,oldPoint: CGPoint,position: CGPoint){
        CATransaction.withDisabledActions{
            let transForm = layer.affineTransform()
            layer.setAffineTransform(.identity)
            layer.frame.origin = point
            layer.setAffineTransform(transForm)
            shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
                guard let self = self else {return}
                let transForm = layer.affineTransform()
                layer.setAffineTransform(.identity)
                targetSelf.translate(layer: layer, point: oldPoint,oldPoint: layer.frame.origin, position: position)
                layer.setAffineTransform(transForm)
                self.selectedVector = layer
            })
            delegate.updateStatus()
        }
    }
    @objc func rotateVector(_ sender: UIRotationGestureRecognizer){
        guard let selectedVector else{return}
        if selectedVector.getLockStatus() || selectedVector.isHidden{
            return
        }
        switch sender.state{
        case .began:
            CATransaction.withDisabledActions {[weak self] in
                guard let self = self else {return}
                let transform = selectedVector.affineTransform()
                selectedVector.setAffineTransform(.identity)
                let oldFrame = selectedVector.frame
                selectedVector.setAffineTransform(transform)
                self.rotateLayerBegin(layer: selectedVector, frame: oldFrame, position: selectedVector.position, transform: transform)
            }
        case .changed:
            CATransaction.withDisabledActions {[weak self] in
                guard let self = self else {return}
                let transform = selectedVector.affineTransform()
                let newTransform = transform.rotated(by: sender.rotation)
                rotateTextCircularly(selectedLayer: selectedVector, value: sender.rotation,newTransform)
            }
        case .ended,.possible,.cancelled,.failed:
            self.delegate.updateStickerSize(layer: selectedVector)
            break
        @unknown default:
            break
        }
        sender.rotation = 0
    }
    func rotateLayerBegin(layer:CALayer,frame:CGRect,position:CGPoint,transform:CGAffineTransform){
        CATransaction.withDisabledActions {[weak self] in
            guard let self = self else {return}
            let oldTransform = layer.affineTransform()
            layer.setAffineTransform(.identity)
            let oldFrame = layer.frame
            let oldPosition = layer.position
            shareUndoManager.registerUndo(withTarget: self, handler: { targetType in
                targetType.rotateLayerBegin(layer: layer, frame: oldFrame, position: oldPosition, transform: oldTransform)
            })
            layer.frame = frame
            layer.position = position
            layer.setAffineTransform(transform)
            selectedVector = layer
            self.delegate.updateStatus()
        }
    }
    func rotateTextCircularly(selectedLayer:CALayer,value : CGFloat,_ transform:CGAffineTransform? = nil){
        let oldTransform = selectedLayer.affineTransform()
        CATransaction.withDisabledActions {[weak self] in
            guard let self = self else {return}
            selectedLayer.setAffineTransform(transform ?? .identity)
            selectedVector = selectedLayer
            self.delegate.updateStatus()
        }
    }
    @objc func doubleTapGestur(){
        guard let selectedVector else{return}
        if selectedVector.getLockStatus() || selectedVector.isHidden{
            return
        }else{
            if selectedVector is SVGTextLayer{
                delegate.changeText()
            }
        }
    }
    @objc func pinchHandler(_ gesture: UIPinchGestureRecognizer) {
        guard let selectedVector else {return}
        if selectedVector.getLockStatus() || selectedVector.isHidden{
            return
        }
        switch gesture.state{
        case .began:
            let transform = selectedVector.affineTransform()
            let frame = selectedVector.frame
            if let textSticker = selectedVector as? SVGTextLayer,let attributedString = textSticker.string as? NSAttributedString{
                self.layerResizeBegan(layer: selectedVector, newFrame: frame, tansform: transform, position: selectedVector.position,attributedString)
            }else{
                self.layerResizeBegan(layer: selectedVector, newFrame: frame, tansform: transform, position: selectedVector.position)
            }
            break
        case .changed:
            CATransaction.withDisabledActions {
                resizeLayer(selectedLayer: selectedVector, scale: gesture.scale)
            }
        case .ended,.possible,.cancelled,.failed:
            self.delegate.updateStickerSize(layer: selectedVector)
            break
        @unknown default:
            break
        }
        gesture.scale = 1
    }
    func layerResizeBegan(layer:CALayer,newFrame:CGRect,tansform:CGAffineTransform,position:CGPoint,_ attributedString:NSAttributedString? = nil){
        CATransaction.withDisabledActions {
            let oldTransform = layer.affineTransform()
            layer.setAffineTransform(.identity)
            let oldFrame = layer.frame
            let oldPosition = layer.position
            var oldAttributedString:NSAttributedString? = nil
            if let textLayer = layer as? SVGTextLayer{
                oldAttributedString = (textLayer.string as? NSAttributedString)
            }
            shareUndoManager.registerUndo(withTarget: self, handler: { targetType in
                targetType.layerResizeBegan(layer: layer, newFrame: oldFrame, tansform: oldTransform, position: oldPosition,oldAttributedString)
            })
            if let textLayer = layer as? SVGTextLayer{
                CATransaction.withDisabledActions{
                    if let attributedString{
                        textLayer.string = attributedString
                    }
                }
            }else if let shapeLayer = layer as? CAShapeLayer{
                CATransaction.withDisabledActions {
                    let scaleWidth  = newFrame.width / oldFrame.width
                    let scaleHeight = newFrame.height / oldFrame.height
                    guard let path = shapeLayer.path?.copy() else {return}
                    let bezierPath = UIBezierPath(cgPath: path)
                    bezierPath.apply(CGAffineTransform(scaleX: scaleWidth, y: scaleHeight))
                    shapeLayer.frame = newFrame
                    shapeLayer.path = bezierPath.cgPath
                }
            }
            layer.frame = newFrame
            layer.position = position
            layer.setAffineTransform(tansform)
        }
        self.delegate.updateStatus()
    }
    func resizeLayer(selectedLayer:CALayer,scale:CGFloat){
        CATransaction.withDisabledActions {
            let oldTransform = selectedLayer.affineTransform()
            selectedLayer.setAffineTransform(.identity)
            let oldFrame = selectedLayer.frame
            let oldPosition = selectedLayer.position
            selectedLayer.frame = CGRect(x: selectedLayer.frame.origin.x, y: selectedLayer.frame.origin.y, width: selectedLayer.frame.width*scale, height: selectedLayer.frame.height*scale)
            if let currentLayer = selectedLayer as? CAShapeLayerWithHitTest{
                let scaleWidth  = currentLayer.frame.width / oldFrame.width
                let scaleHeight = currentLayer.frame.height / oldFrame.height
                guard let path = currentLayer.path?.copy() else {return}
                let bezierPath = UIBezierPath(cgPath: path)
                bezierPath.apply(CGAffineTransform(scaleX: scaleWidth, y: scaleHeight))
                currentLayer.path = bezierPath.cgPath
            }
            selectedLayer.position = oldPosition
            selectedLayer.setAffineTransform(oldTransform)
        }
    }
    // MARK: - Text / Layer Helpers
    
    private func makeAttributedString(_ text: String, fontName: String, size: CGFloat = 80, colorHex: String = "#000000") -> NSAttributedString? {
        guard let font = UIFont(name: fontName, size: size) else { return nil }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(hexString: colorHex)
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }
    
    private func measureTextWidth(for attributed: NSAttributedString, limitingHeight height: CGFloat) -> CGFloat {
        let constraint = CGSize(width: .greatestFiniteMagnitude, height: height)
        let rect = attributed.boundingRect(with: constraint,
                                           options: [.usesLineFragmentOrigin, .usesFontLeading],
                                           context: nil)
        return ceil(rect.width)
    }
    
    // MARK: - Public / Main Methods
    
    func addText(addText: String, _ fontName: String = "Avenir") {
        guard let attributed = makeAttributedString(addText, fontName: fontName, size: 80) else { return }
        
        let textLayer = SVGTextLayer()
        textLayer.string = attributed
        textLayer.contentsScale = UIScreen.main.scale
        
        // size & layout
        changeTextLayerString(textLayer: textLayer, attributes: attributed.attributes(at: 0, effectiveRange: nil))
        addSubLayer(layer: textLayer)
    }
    
    func changeTextLayerString(textLayer: SVGTextLayer, attributes: [NSAttributedString.Key: Any]?) {
        // Ensure there's an attributed string to work with
        guard let current = textLayer.string as? NSAttributedString else { return }
        
        // Build new attributed string from provided attributes (or reuse current attributes)
        let newAttributed = NSAttributedString(string: current.string, attributes: attributes)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        
        textLayer.setAffineTransform(.identity)
        textLayer.string = newAttributed
        
        // Compute width based on font metrics (if font present)
        if let font = attributes?[.font] as? UIFont {
            // Use capHeight or pointSize/descender to compute an appropriate height similar to original.
            let constraintHeight = font.capHeight
            let textWidth = measureTextWidth(for: newAttributed, limitingHeight: constraintHeight)
            let rectHeight = font.pointSize - font.descender
            let oldPosition = textLayer.position
            textLayer.frame = CGRect(x: 0, y: 0, width: textWidth, height: rectHeight)
            textLayer.position = oldPosition
        }
        
        textLayer.contentsScale = UIScreen.main.scale
        selectedVector = textLayer
        delegate.updateStatus()
    }
    
    func addSubLayer(layer: CALayer) {
        // ensure container exists
        guard let container = self.containerView else { return }
        
        // Append to the container's layer
        container.layer.addSublayer(layer)
        
        // Position the new layer in the center of our view
        layer.frame.origin = .zero
        let oldBounds = layer.bounds
        
        // Centering layer within self
        let centerX = (self.bounds.width - layer.frame.width) / 2.0
        let centerY = (self.bounds.height - layer.frame.height) / 2.0
        layer.frame.origin.x = centerX
        layer.frame.origin.y = centerY
        
        // restore bounds as original code intended
        layer.bounds = oldBounds
        layer.backgroundColor = UIColor.clear.cgColor
        
        // track layer & selection
        layers.append(layer)
        selectedVector = layer
        
        // Register undo: removing this layer on undo
        shareUndoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self = self else { return }
            self.deleteLayer(layer: layer)
        }
        
        delegate.updateStatus()
    }
    
    func deleteLayer(layer: CALayer) {
        // If special image-like layer -> keep some flag; otherwise the original code appended it somewhere odd.
        // Preserve original behavior as much as possible but make it safe.
        if !(layer is CALayerWithClipRender) {
            // original code appended to containerView.layer.sublayers? That is odd; we won't mutate sublayers array directly.
            // If you intended to keep a "trash" copy somewhere, consider storing a separate staging array.
            // For now, no-op here to avoid corrupting sublayers array.
        } else {
            // placeholder: original code had a comment about image layer
        }
        // Register undo that re-adds the layer with preserved geometry and visibility
        shareUndoManager.registerUndo(withTarget: self) { [weak self] _ in
            guard let self = self else { return }
            let position = layer.position
            let origin = layer.frame.origin
            let bound = layer.bounds
            
            layer.isHidden = false
            if layer is CALayerWithClipRender {
                // keep the original behavior that set a KVC key for image layers
                layer.setValue("isImage", forKeyPath: "isImage")
            }
            self.addSubLayer(layer: layer)
            layer.position = position
            layer.frame.origin = origin
            layer.bounds = bound
        }
        // Remove from data model and layer hierarchy if present
        if let index = layers.firstIndex(of: layer) {
            if let sublayerIndex = containerView.layer.sublayers?.firstIndex(of: layer) {
                layer.isHidden = true
                containerView.layer.sublayers?.remove(at: sublayerIndex)
                removeLayer(index: index)
            }
        }
        delegate.updateStatus()
    }
    func removeLayer(index: Int) {
        guard layers.indices.contains(index) else { return }
        layers.remove(at: index)
    }
}
public extension SVGEditor{
    func insetImageLayer(image:UIImage,frame:CGRect,_ transform:CGAffineTransform? = .identity) {
        let layer = CAShapeLayer()
        layer.frame = frame
        layer.contents = image.cgImage
        self.containerView.layer.addSublayer(layer)
        layer.frame.origin = .zero
        let oldBounds = layer.bounds
        layer.frame.origin.x = self.frame.width / 2 - layer.frame.width/2
        layer.frame.origin.y = self.containerView.frame.height / 2 - layer.frame.width/2
        layer.bounds = oldBounds
        layer.backgroundColor = UIColor.clear.cgColor
        layer.setAffineTransform(transform ?? .identity)
        layer.position = CGPoint(x: layer.frame.midX, y: layer.frame.midY)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layers.append(layer)
        selectedVector = layer
        shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
            guard let self = self else {return}
            self.deleteLayer(layer: layer)
        })
        delegate?.updateStatus()
    }
    func changeDirection(frame:CGRect,transform:CGAffineTransform, layer : CALayer){
        let oldTransform = layer.affineTransform()
        layer.setAffineTransform(.identity)
        let oldFrame = layer.frame
        shareUndoManager.registerUndo(withTarget: self, handler: { targetType in
            targetType.changeDirection(frame: oldFrame, transform: oldTransform, layer: layer)
        })
        layer.frame = frame
        layer.setAffineTransform(transform)
        self.delegate?.updateStatus()
    }
    func changeTextLayerColor(color: UIColor,textLayer:SVGTextLayer){
        if let textString = (textLayer.string as? NSAttributedString){
            var attributes =  textString.attributes(at: 0, effectiveRange: nil)
            let colorAtrib = attributes.filter({$0.key == .foregroundColor})
            
            if colorAtrib.count == 0{
                let oldColor = UIColor.black
                shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
                    guard let self = self else {return}
                    self.changeTextLayerColor(color: oldColor , textLayer: textLayer)
                })
                let alphaValue = 1
                attributes[NSAttributedString.Key.foregroundColor] = color
                let attributedString = NSAttributedString(string: textString.string, attributes: attributes)
                textLayer.string = attributedString
                changeOpacity(value: Float(alphaValue))
                self.delegate?.updateStatus()
            }else{
                for attribute in attributes{
                    if attribute.key == NSAttributedString.Key.foregroundColor{
                        let oldColor = attribute.value
                        shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
                            guard let self = self else {return}
                            self.changeTextLayerColor(color: oldColor as? UIColor ?? UIColor.white, textLayer: textLayer)
                        })
                        let alphaValue = self.getAlphaValue(textColor: oldColor as? UIColor ?? UIColor.white)
                        attributes[NSAttributedString.Key.foregroundColor] = color
                        let attributedString = NSAttributedString(string: textString.string, attributes: attributes)
                        textLayer.string = attributedString
                        changeOpacity(value: Float(alphaValue))
                        self.delegate?.updateStatus()
                    }
                }
            }
        }
    }
    func changeShapeLayerSize(layer:CALayer,newSize:CGFloat){
        let oldSize = layer.frame.size
        let newWidth: CGFloat = newSize
        let aspectRatio = layer.bounds.size.height / layer.bounds.size.width
        shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
            guard let self = self else {return}
            self.changeShapeLayerSize(layer: layer, newSize: oldSize.width)
        })
        layer.bounds.size.width = newWidth
        layer.bounds.size.height = newWidth * aspectRatio
        self.delegate?.updateStatus()
    }
    func changeShapeLayerColor(color: UIColor,shapeLayer:CAShapeLayer){
        let oldColor = UIColor(cgColor: shapeLayer.fillColor ?? UIColor.red.cgColor)
        let alphaValue = self.getAlphaValue(textColor: oldColor)
        shareUndoManager.registerUndo(withTarget: self, handler: {[weak self](targetSelf) in
            guard let self = self else {return}
            self.changeShapeLayerColor(color: oldColor, shapeLayer: shapeLayer)
            //  self.delegate?.updateSweetRuler(layer: shapeLayer)
        })
        shapeLayer.fillColor = color.cgColor
        changeOpacity(value: Float(alphaValue))
        delegate?.updateStatus()
    }
    func changeClipLayerColor(image: UIImage,clipLayer:CALayer){
        let oldImage = clipLayer.contents as! CGImage
        let oldUIImage = UIImage.init(cgImage: oldImage)
        shareUndoManager.registerUndo(withTarget: self, handler: { targetType in
            targetType.changeClipLayerColor(image: oldUIImage, clipLayer: clipLayer)
        })
        clipLayer.contents = image.cgImage
        delegate?.updateStatus()
    }
    func changeOpacity(value : Float){
        if let textLayer = (selectedVector as? SVGTextLayer ){
            if let textString = (textLayer.string as? NSAttributedString){
                let attributes =  textString.attributes(at: 0, effectiveRange: nil)
                let colorAttribute = attributes.filter({$0.key == .foregroundColor})
                if colorAttribute.count == 0{
                    let color = UIColor.black.withAlphaComponent(CGFloat(value))
                    
                    changeSelectedLayerOpacity(textColor: color, attributedTextString: textString, attributes: attributes, alphaValue: CGFloat(value), textLayer: textLayer)
                    
                }else{
                    guard (attributes[NSAttributedString.Key.font] as? UIFont) != nil else {return}
                    for attribute in attributes{
                        if attribute.key == NSAttributedString.Key.foregroundColor{
                            let color = attribute.value
                            if color is UIColor{
                                if let textColor = color as? UIColor{
                                    if isAlphaChanged(textColor: textColor){
                                    }
                                    changeSelectedLayerOpacity(textColor: textColor, attributedTextString: textString, attributes: attributes, alphaValue: CGFloat(value), textLayer: textLayer)
                                }
                            }else{
                                let textColor = UIColor(cgColor: color as! CGColor).withAlphaComponent(CGFloat(value))
                                changeSelectedLayerOpacity(textColor: textColor, attributedTextString: textString, attributes: attributes, alphaValue: CGFloat(value), textLayer: textLayer)
                            }
                        }
                    }
                }
            }
        }
        else if let shapeLayer = (selectedVector as? CAShapeLayer){
            let color = UIColor(cgColor: shapeLayer.fillColor ?? UIColor.red.cgColor)
            shapeLayer.fillColor = color.withAlphaComponent(CGFloat(value)).cgColor
        }
        else if let shapeLayer = selectedVector{
            if !(((shapeLayer as? SVGTextLayer) != nil)){
                shapeLayer.opacity = value
            }
        }
    }
    func changeSelectedLayerOpacity(textColor : UIColor , attributedTextString : NSAttributedString?, attributes: [NSAttributedString.Key : Any], alphaValue : CGFloat, textLayer : SVGTextLayer){
        var attr = attributes
        if let textString = attributedTextString?.string{
            attr[NSAttributedString.Key.foregroundColor] = textColor.withAlphaComponent(CGFloat(alphaValue))
            let attributedString = NSAttributedString(string: textString, attributes: attr)
            textLayer.string = attributedString
        }
    }
    func isAlphaChanged(textColor : UIColor) -> Bool{
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        textColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        if alpha >= 0.99{
            return false
        }else{
            return true
        }
    }
    func getAlphaValue(textColor : UIColor) -> CGFloat{
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        textColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return alpha
    }
    // Duplicate an SVGTextLayer (preserving NSAttributedString and common layer properties)
    func duplicateTextLayer(_ original: SVGTextLayer, offset: CGPoint = CGPoint(x: 16, y: 16)) -> SVGTextLayer? {
        guard let container = self.containerView else { return nil }
        guard original.superlayer != nil else { return nil }
        
        // Create a new instance of the same concrete type
        let copy: SVGTextLayer
        if let ctor = type(of: original) as? SVGTextLayer.Type {
            copy = ctor.init()
        } else {
            copy = SVGTextLayer()
        }
        
        // --- Copy common CALayer properties ---
        copy.bounds = original.bounds
        // place copy with offset relative to original's frame
        let origFrame = original.frame
        copy.frame = CGRect(origin: CGPoint(x: origFrame.origin.x + offset.x, y: origFrame.origin.y + offset.y),
                            size: origFrame.size)
        copy.anchorPoint = original.anchorPoint
        copy.transform = original.transform
        copy.opacity = original.opacity
        copy.isHidden = original.isHidden
        copy.zPosition = original.zPosition
        copy.contentsScale = original.contentsScale
        copy.backgroundColor = original.backgroundColor
        
        // --- Copy text-specific content (NSAttributedString) ---
        if let attr = original.string as? NSAttributedString {
            // Make an independent copy of attributed string
            copy.string = attr.mutableCopy() as? NSAttributedString
            // If you have a helper that expects attributes dictionary:
            let attrs = attr.attributes(at: 0, effectiveRange: nil)
            changeTextLayerString(textLayer: copy, attributes: attrs)
        } else if let str = original.string as? String {
            let newAttr = makeAttributedString(str, fontName: "Avenir", size: 80) ?? NSAttributedString(string: str)
            copy.string = newAttr
            changeTextLayerString(textLayer: copy, attributes: newAttr.attributes(at: 0, effectiveRange: nil))
        }
        
        // If your SVGTextLayer has a custom attributed property use that instead:
        // copy.attributedString = original.attributedString?.mutableCopy() as? NSAttributedString
        
        // --- Add to container layer (preserve exact position) ---
        container.layer.addSublayer(copy)
        
        // Track layer & selection (same steps as addSubLayer)
        layers.append(copy)
        selectedVector = copy
        
        // Register undo: removing this duplicated layer on undo
        shareUndoManager.registerUndo(withTarget: self) { [weak self] target in
            guard let self = self else { return }
            self.deleteLayer(layer: copy)
        }
        
        delegate.updateStatus()
        
        return copy
    }
    func updatgeText(text:String){
        guard let selectedVector else {return}
        if let textLayer = selectedVector as? SVGTextLayer {
            if let textString = textLayer.string as? NSAttributedString{
                shareUndoManager.registerUndo(withTarget: self, handler: {targetSelf in
                    targetSelf.updatgeText(text: textString.string)
                })
                let attributes =  textString.attributes(at: 0, effectiveRange: nil)
                textLayer.string = NSAttributedString(string: text, attributes: attributes)
                self.changeTextLayerString(textLayer: textLayer, attributes: attributes)
                self.delegate?.updateStatus()
            }
        }
    }
    func changeTextFont(name:String){
        guard let selectedVector else {return}
        if let textLayer = selectedVector as? SVGTextLayer {
            if let textString = (textLayer.string as? NSAttributedString){
                var attributes =  textString.attributes(at: 0, effectiveRange: nil)
                guard let font = attributes[NSAttributedString.Key.font] as? UIFont else {return}
                shareUndoManager.registerUndo(withTarget: self, handler: { targetType in
                    targetType.changeTextFont(name: font.fontName)
                })
                let newFont = UIFont(name: name, size: font.pointSize) ?? UIFont.systemFont(ofSize: font.pointSize)
                attributes[NSAttributedString.Key.font] = newFont
                self.changeTextLayerString(textLayer: textLayer, attributes: attributes)
                
            }
        }
    }
    func updateFontSize(size:CGFloat){
        if let textLayer = (selectedVector as? SVGTextLayer ){
            if let textString = (textLayer.string as? NSAttributedString){
                let attributes =  textString.attributes(at: 0, effectiveRange: nil)
                guard let font = attributes[NSAttributedString.Key.font] as? UIFont else {return}
                let newFont = UIFont(descriptor: font.fontDescriptor , size: size)
                updateTextLayerFont(font: newFont, textLayer: textLayer)
            }
        }
    }
    func updateTextLayerFont(font:UIFont,textLayer:SVGTextLayer){
        if let oldFont = textLayer.fontAtLocation(location: 0){
            shareUndoManager.registerUndo(withTarget: self) { targetType in
                targetType.updateTextLayerFont(font: oldFont, textLayer: textLayer)
            }
            if let textString = textLayer.string as? NSAttributedString{
                var attributes =  textString.attributes(at: 0, effectiveRange: nil)
                attributes[NSAttributedString.Key.font] = font
                let attributedString = NSAttributedString(string: textString.string, attributes: attributes)
                CATransaction.withDisabledActions {
                    let oldPosition = textLayer.position
                    textLayer.string = attributedString
                    let oldTrans = textLayer.affineTransform()
                    textLayer.setAffineTransform(.identity)
                    let constraintBox = CGSize(width: .greatestFiniteMagnitude, height: font.capHeight)
                    let textWidth = attributedString.boundingRect(with: constraintBox, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).width.rounded(.up)
                    let rectHeight = font.pointSize - font.descender
                    let newFrame = CGRect(x: textLayer.frame.origin.x, y: textLayer.frame.origin.y, width: textWidth, height: rectHeight)
                    textLayer.frame = newFrame
                    textLayer.position = oldPosition
                    textLayer.setAffineTransform(oldTrans)
                    selectedVector = textLayer
                    delegate.updateStatus()
                }
            }
        }
    }
}
public extension SVGTextLayer {
    func fontAtLocation(location: Int) -> UIFont? {
        if let attributedString = self.string as? NSAttributedString {
            let font = attributedString.attribute(.font, at: location, effectiveRange: nil) as? UIFont
            return font
        }
        return nil
    }
    func strokeWidthAtLocation(location: Int) -> CGFloat? {
        if let attributedString = self.string as? NSAttributedString {
            let strokeWidth = attributedString.attribute(.strokeWidth, at: location, effectiveRange: nil) as? CGFloat
            return strokeWidth
        }
        return nil
    }
}

open class Test:UIView{
    
}

#endif
