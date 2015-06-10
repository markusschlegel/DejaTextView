//
//  DejaTextView.swift
//  DejaTextView
//
//  Created by Markus Schlegel on 17/05/15.
//  Copyright (c) 2015 Markus Schlegel. All rights reserved.
//

import UIKit







let animation_duration: Double = 0.2
let animation_spring_damping: CGFloat = 0.8
let grabber_frame: CGRect = CGRectMake(0, 0, 88, 43)
let selection_alpha: CGFloat = 0.4
let caret_tap_radius: CGFloat = 20.0
let repositioning_timer_duration: Double = 1.0
let start_grabber_y_offset: CGFloat = 20.0              // while dragging, the start grabber will be vertically positioned at this offset (0 is top edge)
let end_grabber_y_offset: CGFloat = 23.0                // while dragging, the end grabber will be vertically positioned at this offset (0 is top edge)
let start_grabber_tip_selection_offset: CGFloat = 20.0  // while dragging, the selection start will be set to the tip position + this offset
let end_grabber_tip_selection_offset: CGFloat = 20.0    // while dragging, the selection end will be set to the tip position - this offset







/// A UITextView subclass with improved text selection and cursor movement tools
public class DejaTextView: UITextView
{
    private enum DejaTextGrabberTipDirection
    {
        case Down
        case Up
    }
    
    
    
    private enum DejaTextGrabberTipAlignment
    {
        case Left
        case Right
        case Center
    }
    
    
    
    private struct CurvyPath {
        let startPoint: (CGFloat, CGFloat)
        let curves: [((CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat))]
        
        func toBezierPath() -> UIBezierPath {
            let path = UIBezierPath()
            path.moveToPoint(CGPointMake(self.startPoint.0, self.startPoint.1))
            
            for ((x, y), (cp1x, cp1y), (cp2x, cp2y)) in self.curves {
                path.addCurveToPoint(CGPointMake(x, y), controlPoint1: CGPointMake(cp1x, cp1y), controlPoint2: CGPointMake(cp2x, cp2y))
            }
            
            return path
        }
        
        func toBezierPath() -> CGPathRef {
            return self.toBezierPath().CGPath
        }
    }
    
    
    
    private struct LineyPath {
        let startPoint: (CGFloat, CGFloat)
        let linePoints: [(CGFloat, CGFloat)]
        
        func toBezierPath() -> UIBezierPath {
            let path = UIBezierPath()
            path.moveToPoint(CGPointMake(self.startPoint.0, self.startPoint.1))
            
            for (x, y) in self.linePoints {
                path.addLineToPoint(CGPointMake(x, y))
            }
            
            return path
        }
        
        func toBezierPath() -> CGPathRef {
            return self.toBezierPath().CGPath
        }
    }
    
    
    
    private class DejaTextGrabber: UIView
    {
        let tipDirection: DejaTextGrabberTipDirection
        var tipPosition = CGPointZero
        var extended = true
        var forcedTipAlignment: DejaTextGrabberTipAlignment? = nil
        
        private let _body = CAShapeLayer()
        private let _leftTriangle = CAShapeLayer()
        private let _rightTriangle = CAShapeLayer()
        private let _separator = CAShapeLayer()
        
        
        
        func transform(#animated: Bool) {
            var newOrigin = self.tipPosition
            
            if let superView = self.superview {
                let window: UIWindow? = UIApplication.sharedApplication().keyWindow
                let xtreshold = self.frame.size.width / 2.0
                var newPaths: (CGPath, CGPathRef?, CGPathRef?, CGPathRef?)
                let alignment: DejaTextGrabberTipAlignment
                
                if self.forcedTipAlignment != nil {
                    alignment = self.forcedTipAlignment!
                } else {
                    if self.tipPosition.x < xtreshold {
                        alignment = .Left
                    } else if self.tipPosition.x > superView.frame.size.width - xtreshold {
                        alignment = .Right
                    } else {
                        alignment = .Center
                    }
                }
                
                if alignment == .Left {
                    newOrigin.x -= 14.0
                } else if alignment == .Right {
                    newOrigin.x -= 74.0
                } else {
                    newOrigin.x -= 44.0
                }
                
                
                newPaths = self.paths(tipDirection: self.tipDirection, tipAlignment: alignment, extended: self.extended)
                
                if self.tipDirection == .Down {
                    newOrigin.y -= 43.0
                }
                
                
                // Morph animation
                _body.removeAllAnimations()
                let morphAnimation = CABasicAnimation(keyPath: "path")
                morphAnimation.duration = animation_duration
                morphAnimation.fromValue = _body.presentationLayer().path
                morphAnimation.toValue = newPaths.0
                
                _body.path = newPaths.0
                if animated {
                    _body.addAnimation(morphAnimation, forKey: "morph")
                }
                
                
                // Fade animation
                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.duration = animation_duration
                fadeAnimation.fromValue = _leftTriangle.presentationLayer().opacity
                if let left = newPaths.1, right = newPaths.2, separator = newPaths.3 {
                    fadeAnimation.toValue = 1.0
                    
                    CATransaction.begin()
                    CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
                    _leftTriangle.opacity = 1.0
                    _rightTriangle.opacity = 1.0
                    _separator.opacity = 1.0
                    CATransaction.commit()
                    
                    _leftTriangle.path = left
                    _rightTriangle.path = right
                    _separator.path = separator
                } else {
                    fadeAnimation.toValue = 0.0
                    
                    CATransaction.begin()
                    CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
                    _leftTriangle.opacity = 0.0
                    _rightTriangle.opacity = 0.0
                    _separator.opacity = 0.0
                    CATransaction.commit()
                }
                
                if animated && _leftTriangle.animationForKey("fade") == nil && fadeAnimation.fromValue !== fadeAnimation.toValue {
                    _leftTriangle.addAnimation(fadeAnimation, forKey: "fade");
                }
                
                if animated && _rightTriangle.animationForKey("fade") == nil && fadeAnimation.fromValue !== fadeAnimation.toValue {
                    _rightTriangle.addAnimation(fadeAnimation, forKey: "fade");
                }
                
                if animated && _separator.animationForKey("fade") == nil && fadeAnimation.fromValue !== fadeAnimation.toValue {
                    _separator.addAnimation(fadeAnimation, forKey: "fade");
                }
                
                
                // Frame (position) animation
                let a: (Void) -> Void = {
                    var newFrame = self.frame
                    newFrame.origin = newOrigin
                    self.frame = newFrame
                }
                
                if animated {
                    UIView.animateWithDuration(animation_duration, delay: 0.0, usingSpringWithDamping: animation_spring_damping, initialSpringVelocity: 0.0, options: nil, animations: a, completion: nil)
                } else {
                    a()
                }
            }
        }
        
        
        
        init(frame: CGRect, tipDirection: DejaTextGrabberTipDirection) {
            self.tipDirection = tipDirection
            super.init(frame: frame)
            
            _body.frame = grabber_frame
            _body.fillColor = UIColor.blackColor().CGColor
            _body.path = self.paths(tipDirection: self.tipDirection, tipAlignment: .Center, extended: true).0
            
            _leftTriangle.frame = grabber_frame
            _leftTriangle.fillColor = UIColor.whiteColor().CGColor
            _leftTriangle.path = self.paths(tipDirection: self.tipDirection, tipAlignment: .Center, extended: true).1
            
            _rightTriangle.frame = grabber_frame
            _rightTriangle.fillColor = UIColor.whiteColor().CGColor
            _rightTriangle.path = self.paths(tipDirection: self.tipDirection, tipAlignment: .Center, extended: true).2
            
            _separator.frame = grabber_frame
            _separator.fillColor = UIColor.whiteColor().CGColor
            _separator.path = self.paths(tipDirection: self.tipDirection, tipAlignment: .Center, extended: true).3
            
            self.layer.addSublayer(_body)
            self.layer.addSublayer(_leftTriangle)
            self.layer.addSublayer(_rightTriangle)
            self.layer.addSublayer(_separator)
        }
        
        
        
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        
        override func intrinsicContentSize() -> CGSize {
            return grabber_frame.size
        }
        
        
        
        override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
            if self.extended {
                return CGRectContainsPoint(self.bounds, point)
            } else {
                return CGPathContainsPoint(_body.path, nil, point, false)
            }
        }
        
        
        
        func paths(#tipDirection: DejaTextGrabberTipDirection, tipAlignment: DejaTextGrabberTipAlignment, extended: Bool) -> (CGPath, CGPath?, CGPath?, CGPath?) {
            if extended {
                return self.extendedPaths(tipDirection: tipDirection, tipAlignment: tipAlignment)
            } else {
                return self.unextendedPaths(tipDirection: tipDirection, tipAlignment: tipAlignment)
            }
        }
        
        
        
        func extendedPaths(#tipDirection: DejaTextGrabberTipDirection, tipAlignment: DejaTextGrabberTipAlignment) -> (CGPath, CGPath?, CGPath?, CGPath?) {
            let l, r, c : LineyPath
            
            if tipDirection == .Up {
                l = LineyPath(startPoint: (18, 26), linePoints: [
                    (25, 19),
                    (25, 33),
                    (18, 26),
                    ])
                
                r = LineyPath(startPoint: (69, 26), linePoints: [
                    (62, 33),
                    (62, 19),
                    (69, 26),
                    ])
                
                c = LineyPath(startPoint: (43.5, 0), linePoints: [
                    (44.5, 0),
                    (44.5, 43),
                    (43.5, 43),
                    (43.5, 0),
                    ])
            } else {
                l = LineyPath(startPoint: (18, 26-9), linePoints: [
                    (25, 19-9),
                    (25, 33-9),
                    (18, 26-9),
                    ])
                
                r = LineyPath(startPoint: (69, 26-9), linePoints: [
                    (62, 33-9),
                    (62, 19-9),
                    (69, 26-9),
                    ])
                
                c = LineyPath(startPoint: (43.5, 0), linePoints: [
                    (44.5, 0),
                    (44.5, 43),
                    (43.5, 43),
                    (43.5, 0),
                    ])
            }
            
            let left: CGPathRef = l.toBezierPath()
            let right: CGPathRef = r.toBezierPath()
            let separator: CGPathRef = c.toBezierPath()
            
            if tipDirection == .Up && tipAlignment == .Left {
                return (self.extendedTipUpLeftPaths(), left, right, separator)
            } else if tipDirection == .Up && tipAlignment == .Right {
                return (self.extendedTipUpRightPaths(), left, right, separator)
            } else if tipDirection == .Up && tipAlignment == .Center {
                return (self.extendedTipUpPaths(), left, right, separator)
            } else if tipDirection == .Down && tipAlignment == .Left {
                return (self.extendedTipDownLeftPaths(), left, right, separator)
            } else if tipDirection == .Down && tipAlignment == .Right {
                return (self.extendedTipDownRightPaths(), left, right, separator)
            } else {
                return (self.extendedTipDownPaths(), left, right, separator)
            }
        }
        
        
        
        func unextendedPaths(#tipDirection: DejaTextGrabberTipDirection, tipAlignment: DejaTextGrabberTipAlignment) -> (CGPath, CGPath?, CGPath?, CGPath?) {
            if tipDirection == .Up && tipAlignment == .Left {
                return (self.unextendedTipUpLeftPaths(), nil, nil, nil)
            } else if tipDirection == .Up && tipAlignment == .Right {
                return (self.unextendedTipUpRightPaths(), nil, nil, nil)
            } else if tipDirection == .Up && tipAlignment == .Center {
                return (self.unextendedTipUpPaths(), nil, nil, nil)
            } else if tipDirection == .Down && tipAlignment == .Left {
                return (self.unextendedTipDownLeftPaths(), nil, nil, nil)
            } else if tipDirection == .Down && tipAlignment == .Right {
                return (self.unextendedTipDownRightPaths(), nil, nil, nil)
            } else {
                return (self.unextendedTipDownPaths(), nil, nil, nil)
            }
        }
        
        
        
        func extendedTipUpPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (44, 0), curves: [
                ((53, 9), (44, 0), (53, 9)),
                ((72, 9), (53, 9), (72, 9)),
                ((88, 26), (81, 9), (88, 17)),
                ((72, 43), (88, 35), (81, 43)),
                ((16, 43), (72, 43), (16, 43)),
                ((0, 26), (7, 43), (0, 35)),
                ((16, 9), (0, 17), (7, 9)),
                ((35, 9), (16, 9), (35, 9)),
                ((44, 0), (35, 9), (44, 0)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func extendedTipUpLeftPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (14, 0), curves: [
                ((22, 9), (16, 2), (14, 9)),
                ((72, 9), (22, 9), (72, 9)),
                ((88, 26), (81, 9), (88, 17)),
                ((72, 43), (88, 35), (81, 43)),
                ((16, 43), (72, 43), (16, 43)),
                ((0, 26), (7, 43), (0, 35)),
                ((14, 0), (0, 17), (3, 10)),
                ((14, 0), (14, 0), (14, 0)),
                ((14, 0), (14, 0), (14, 0)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func extendedTipUpRightPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (74, 0), curves: [
                ((74, 0), (74, 0), (74, 0)),
                ((74, 0), (74, 0), (74, 0)),
                ((88, 26), (85, 10), (88, 17)),
                ((72, 43), (88, 35), (81, 43)),
                ((16, 43), (72, 43), (16, 43)),
                ((0, 26), (7, 43), (0, 35)),
                ((16, 9), (0, 17), (7, 9)),
                ((66, 9), (16, 9), (66, 9)),
                ((74, 0), (74, 9), (72, 2)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipUpPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (44, 0), curves: [
                ((47, 5), (44, 0), (46, 3)),
                ((47, 5), (47, 5), (47, 5)),
                ((52, 15), (48, 7), (52, 10)),
                ((44, 23), (52, 20), (48, 23)),
                ((44, 23), (44, 23), (44, 23)),
                ((36, 15), (40, 23), (36, 20)),
                ((41, 5), (36, 10), (40, 7)),
                ((41, 5), (41, 5), (41, 5)),
                ((44, 0), (42, 3), (44, 0)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipUpLeftPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (14, 0), curves: [
                ((17, 5), (14, 0), (16, 3)),
                ((17, 5), (17, 5), (17, 5)),
                ((22, 15), (18, 7), (22, 10)),
                ((14, 23), (22, 20), (18, 23)),
                ((14, 23), (14, 23), (14, 23)),
                ((6, 15), (10, 23), (6, 20)),
                ((11, 5), (6, 10), (10, 7)),
                ((11, 5), (11, 5), (11, 5)),
                ((14, 0), (12, 3), (14, 0)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipUpRightPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (74, 0), curves: [
                ((77, 5), (74, 0), (76, 3)),
                ((77, 5), (77, 5), (77, 5)),
                ((82, 15), (78, 7), (82, 10)),
                ((74, 23), (82, 20), (78, 23)),
                ((74, 23), (74, 23), (74, 23)),
                ((66, 15), (70, 23), (66, 20)),
                ((71, 5), (66, 10), (70, 7)),
                ((71, 5), (71, 5), (71, 5)),
                ((74, 0), (72, 3), (74, 0)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func extendedTipDownPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (44, 43), curves: [
                ((53, 34), (44, 43), (53, 34)),
                ((72, 34), (53, 34), (72, 34)),
                ((88, 17), (81, 34), (88, 26)),
                ((72, 0), (88, 8), (81, 0)),
                ((16, 0), (72, 0), (16, 0)),
                ((0, 17), (7, 0), (0, 8)),
                ((16, 34), (0, 26), (7, 34)),
                ((35, 34), (16, 34), (35, 34)),
                ((44, 43), (35, 34), (44, 43)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func extendedTipDownLeftPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (14, 43), curves: [
                ((22, 34), (16, 41), (14, 34)),
                ((72, 34), (22, 34), (72, 34)),
                ((88, 17), (81, 34), (88, 26)),
                ((72, 0), (88, 8), (81, 0)),
                ((16, 0), (72, 0), (16, 0)),
                ((0, 17), (7, 0), (0, 8)),
                ((14, 43), (0, 26), (3, 33)),
                ((14, 43), (14, 43), (14, 43)),
                ((14, 43), (14, 43), (14, 43)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func extendedTipDownRightPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (74, 43), curves: [
                ((66, 34), (72, 41), (74, 34)),
                ((16, 34), (66, 34), (16, 34)),
                ((0, 17), (7, 34), (0, 26)),
                ((16, 0), (0, 8), (7, 0)),
                ((72, 0), (16, 0), (72, 0)),
                ((88, 17), (81, 0), (88, 8)),
                ((74, 43), (88, 26), (85, 33)),
                ((74, 43), (74, 43), (74, 43)),
                ((74, 43), (74, 43), (74, 43)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipDownPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (44, 43), curves: [
                ((47, 38), (44, 43), (46, 40)),
                ((47, 38), (47, 38), (47, 38)),
                ((52, 28), (48, 36), (52, 33)),
                ((44, 413), (52, 410), (48, 413)),
                ((44, 413), (44, 413), (44, 413)),
                ((36, 28), (40, 413), (36, 410)),
                ((41, 38), (36, 33), (40, 36)),
                ((41, 38), (41, 38), (41, 38)),
                ((44, 43), (42, 43-3), (44, 43)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipDownLeftPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (14, 43), curves: [
                ((17, 38), (14, 43), (16, 40)),
                ((17, 38), (17, 38), (17, 38)),
                ((22, 28), (18, 36), (22, 33)),
                ((14, 413), (22, 410), (18, 413)),
                ((14, 413), (14, 413), (14, 413)),
                ((6, 28), (10, 413), (6, 410)),
                ((11, 38), (6, 33), (10, 36)),
                ((11, 38), (11, 38), (11, 38)),
                ((14, 43), (12, 40), (14, 43)),
                ])
            
            return b.toBezierPath()
        }
        
        
        
        func unextendedTipDownRightPaths() -> CGPathRef {
            let b = CurvyPath(startPoint: (74, 43), curves: [
                ((77, 38), (74, 43), (76, 40)),
                ((77, 38), (77, 38), (77, 38)),
                ((82, 28), (78, 36), (82, 33)),
                ((74, 413), (82, 410), (78, 413)),
                ((74, 413), (74, 413), (74, 413)),
                ((66, 28), (70, 413), (66, 410)),
                ((71, 38), (66, 33), (70, 36)),
                ((71, 38), (71, 38), (71, 38)),
                ((74, 43), (72, 43-3), (74, 43)),
                ])
            
            return b.toBezierPath()
        }
    }
    
    
    
    
    
    
    
    // MARK: - Properties
    
    private let _startGrabber = DejaTextGrabber(frame: grabber_frame, tipDirection: .Down)
    private let _endGrabber = DejaTextGrabber(frame: grabber_frame, tipDirection: .Up)
    
    private var _selectionLayers = [CALayer]()
    
    lazy private var _singleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "singleTapped:")
    lazy private var _doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "doubleTapped:")
    lazy private var _tripleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "tripleTapped:")
    lazy private var _startGrabberTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "startGrabberTapped:")
    lazy private var _endGrabberTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "endGrabberTapped:")
    lazy private var _startGrabberPanRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "startGrabberPanned:")
    lazy private var _endGrabberPanRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "endGrabberPanned:")
    
    private var _keyboardFrame = CGRectZero
    
    private var _startGrabberIsBeingManipulated = false
    private var _endGrabberIsBeingManipulated = false
    
    private var _startGrabberRepositioningTimer: NSTimer?
    private var _endGrabberRepositioningTimer: NSTimer?
    
    private var _panOffset = CGPointZero
    
    
    
    
    
    
    
    // MARK: - Initialization
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.configure()
    }

    
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.configure()
    }
    
    
    
    private func configure() -> Void {
        self.addSubview(_startGrabber)
        self.addSubview(_endGrabber)
        
        _singleTapRecognizer.numberOfTapsRequired = 1
        _singleTapRecognizer.requireGestureRecognizerToFail(_startGrabberTapRecognizer)
        _singleTapRecognizer.requireGestureRecognizerToFail(_endGrabberTapRecognizer)
        super.addGestureRecognizer(_singleTapRecognizer)
        
        _doubleTapRecognizer.numberOfTapsRequired = 2
        _doubleTapRecognizer.requireGestureRecognizerToFail(_startGrabberTapRecognizer)
        _doubleTapRecognizer.requireGestureRecognizerToFail(_endGrabberTapRecognizer)
        super.addGestureRecognizer(_doubleTapRecognizer)
        
        _tripleTapRecognizer.numberOfTapsRequired = 3
        _tripleTapRecognizer.requireGestureRecognizerToFail(_startGrabberTapRecognizer)
        _tripleTapRecognizer.requireGestureRecognizerToFail(_endGrabberTapRecognizer)
        super.addGestureRecognizer(_tripleTapRecognizer)
        
        _startGrabber.addGestureRecognizer(_startGrabberTapRecognizer)
        _endGrabber.addGestureRecognizer(_endGrabberTapRecognizer)
        
        _startGrabber.addGestureRecognizer(_startGrabberPanRecognizer)
        _endGrabber.addGestureRecognizer(_endGrabberPanRecognizer)
        
        _startGrabber.hidden = true
        _endGrabber.hidden = true
        
        _keyboardFrame = CGRectMake(0, UIScreen.mainScreen().bounds.height, UIScreen.mainScreen().bounds.width, 1.0)
        
        NSNotificationCenter.defaultCenter().addObserverForName(UITextViewTextDidChangeNotification, object: self, queue: NSOperationQueue.mainQueue()) {
            (notification) in
            self.selectedTextRangeDidChange()
            
            self._endGrabber.extended = false
            self._endGrabber.transform(animated: true)
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillChangeFrameNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            (notification) in
            if let info = notification.userInfo {
                if let frame = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() {
                    self._keyboardFrame = frame
                }
            }
        }
    }
    
    
    
    
    
    
    
    // MARK: - Misc
    
    private func selectedTextRangeDidChange() {
        for l in _selectionLayers {
            l.removeFromSuperlayer()
        }
        _selectionLayers.removeAll(keepCapacity: true)
        
        if let range = self.selectedTextRange {
            if range.empty {
                let r = self.caretRectForPosition(range.start)
                if !_endGrabberIsBeingManipulated {
                    _endGrabber.tipPosition = CGPointMake(r.origin.x + 0.5 * r.size.width, r.origin.y + r.size.height)
                    _endGrabber.transform(animated: false)
                }
                
                _startGrabber.hidden = true
                _endGrabber.hidden = false
            } else {
                let rects: [UITextSelectionRect] = super.selectionRectsForRange(range) as! [UITextSelectionRect]
                for r in rects {
                    let l = CALayer()
                    l.frame = r.rect
                    l.backgroundColor = self.tintColor.colorWithAlphaComponent(selection_alpha).CGColor
                    _selectionLayers += [l]
                    self.layer.insertSublayer(l, atIndex: 0)
                }
                
                let (topLeft, bottomRight) = self.selectionCorners()
                
                if !_startGrabberIsBeingManipulated {
                    _startGrabber.tipPosition = topLeft
                    _startGrabber.transform(animated: false)
                }
                
                if !_endGrabberIsBeingManipulated {
                    _endGrabber.tipPosition = bottomRight
                    _endGrabber.transform(animated: false)
                }
                
                _startGrabber.hidden = false
                _endGrabber.hidden = false
            }
        }
    }
    
    
    
    
    
    
    
    // MARK: - Overrides
    
    override public var selectedTextRange: UITextRange? {
        didSet {
            self.selectedTextRangeDidChange()
        }
    }
    
    
    
    override public func addGestureRecognizer(gestureRecognizer: UIGestureRecognizer) {
        // Only allow native scrolling
        if gestureRecognizer == self.panGestureRecognizer {
            super.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    
    
    
    
    
    
    
    // MARK: - Public methods
    
    /**
        Use this method to add your own gesture recognizers.
    
        :param: gestureRecognizer An object whose class descends from the UIGestureRecognizer class.
    */
    internal func addGestureRecognizerForReal(gestureRecognizer: UIGestureRecognizer) {
        super.addGestureRecognizer(gestureRecognizer)
    }
    
    
    
    
    
    
    
    // MARK: - Action methods
    
    @objc private func singleTapped(recognizer: UITapGestureRecognizer) {
        if !self.isFirstResponder() {
            self.becomeFirstResponder()
        }
        
        let location = recognizer.locationInView(self)
        let closest = self.closestPositionToPoint(location)
        
        
        // Check whether the tap happened in the vicinity of the caret
        if self.selectedRange.length == 0 {
            let caretRect = self.caretRectForPosition(self.selectedTextRange?.start)
            let d = distanceFrom(point: location, toRect: caretRect)
            
            if d <= caret_tap_radius {
                self.showEditingMenu()
                
                _endGrabber.extended = true
                _endGrabber.transform(animated: true)
                
                return
            }
        }
        
        
        // Tap inside or outside of words
        if self.tokenizer.isPosition(self.closestPositionToPoint(location)!, withinTextUnit: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue) && self.tokenizer.isPosition(self.closestPositionToPoint(location)!, withinTextUnit: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue) {
            var rightLeft = self.tokenizer.positionFromPosition(closest, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue)
            rightLeft = self.tokenizer.positionFromPosition(rightLeft!, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue)
            let rightLeftRect = self.caretRectForPosition(rightLeft)
            
            var leftRight = self.tokenizer.positionFromPosition(closest, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue)
            leftRight = self.tokenizer.positionFromPosition(leftRight!, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue)
            let leftRightRect = self.caretRectForPosition(leftRight)
            
            if distanceFrom(point: location, toRect: rightLeftRect) < distanceFrom(point: location, toRect: leftRightRect) {
                self.selectedTextRange = self.textRangeFromPosition(rightLeft, toPosition: rightLeft)
            } else {
                self.selectedTextRange = self.textRangeFromPosition(leftRight, toPosition: leftRight)
            }
        } else {
            self.selectedTextRange = self.textRangeFromPosition(closest, toPosition: closest)
        }
        
        self.hideEditingMenu()
        
        _endGrabber.extended = false
        _endGrabber.transform(animated: false)
    }
    
    
    
    @objc private func doubleTapped(recognizer: UITapGestureRecognizer) {
        if !self.isFirstResponder() {
            self.becomeFirstResponder()
        }
        
        let location = recognizer.locationInView(self)
        let closest = self.closestPositionToPoint(location)
        
        var range = self.tokenizer.rangeEnclosingPosition(closest, withGranularity: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue)
        
        if range == nil {
            range = self.tokenizer.rangeEnclosingPosition(closest, withGranularity: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue)
        }
        
        if range != nil {
            self.selectedTextRange = range;
        } else {
            var right: UITextPosition?
            var rightRight: UITextPosition?
            var left: UITextPosition?
            var leftLeft: UITextPosition?
            
            right = self.tokenizer.positionFromPosition(closest, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue)
            if right != nil {
                rightRight = self.tokenizer.positionFromPosition(right!, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Right.rawValue)
            }
            left = self.tokenizer.positionFromPosition(closest, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue)
            if left != nil {
                leftLeft = self.tokenizer.positionFromPosition(left!, toBoundary: UITextGranularity.Word, inDirection: UITextLayoutDirection.Left.rawValue)
            }
            
            let rightRect = self.caretRectForPosition(right)
            let leftRect = self.caretRectForPosition(left)
            
            if distanceFrom(point: location, toRect: rightRect) < distanceFrom(point: location, toRect: leftRect) {
                self.selectedTextRange = self.textRangeFromPosition(right, toPosition: rightRight)
            } else {
                self.selectedTextRange = self.textRangeFromPosition(left, toPosition: leftLeft)
            }
        }
        
        _startGrabber.extended = true
        _startGrabber.transform(animated: false)
        _endGrabber.extended = true
        _endGrabber.transform(animated: false)
        
        self.showEditingMenu()
    }
    
    
    
    @objc private func tripleTapped(recognizer: UITapGestureRecognizer) {
        if !self.isFirstResponder() {
            self.becomeFirstResponder()
        }
        
        let range = self.textRangeFromPosition(self.beginningOfDocument, toPosition: self.endOfDocument)
        self.selectedTextRange = range
        
        _startGrabber.extended = true
        _startGrabber.transform(animated: false)
        _endGrabber.extended = true
        _endGrabber.transform(animated: false)
        
        self.showEditingMenu()
    }
    
    
    
    @objc private func startGrabberTapped(recognizer: UITapGestureRecognizer) {
        if !_startGrabber.extended {
            self.showEditingMenu()
            
            _startGrabber.extended = true
            _startGrabber.transform(animated: true)
            return
        }
        
        _startGrabberIsBeingManipulated = true
        
        
        // Set the timer
        _startGrabberRepositioningTimer?.invalidate()
        _startGrabberRepositioningTimer = NSTimer.scheduledTimerWithTimeInterval(repositioning_timer_duration, target: self, selector: "startGrabberRepositioningTimerFired:", userInfo: nil, repeats: false)
        
        
        // Set text range according to the button that has been tapped
        var pos = self.selectedRange.location
        var len = self.selectedRange.length
        
        let location = recognizer.locationInView(_startGrabber)
        
        if location.x <= _startGrabber.bounds.size.width / 2.0 {
            if pos != 0 {
                pos--
                len++
            }
        } else {
            if len != 1 {
                pos++
                len--
            }
        }
        
        self.selectedTextRange = self.textRangeFromPosition(self.positionFromPosition(self.beginningOfDocument, offset: pos), toPosition: self.positionFromPosition(self.beginningOfDocument, offset: pos + len))
        
        
        // Show editing menu
        self.showEditingMenu()
    }
    
    
    
    @objc private func endGrabberTapped(recognizer: UITapGestureRecognizer) {
        if !_endGrabber.extended {
            self.showEditingMenu()
            
            _endGrabber.extended = true
            _endGrabber.transform(animated: true)
            return
        }
        
        _endGrabberIsBeingManipulated = true
        
        
        // Set the timer
        _endGrabberRepositioningTimer?.invalidate()
        _endGrabberRepositioningTimer = NSTimer.scheduledTimerWithTimeInterval(repositioning_timer_duration, target: self, selector: "endGrabberRepositioningTimerFired:", userInfo: nil, repeats: false)
        
        
        // Set text range according to the button that has been tapped
        var pos = self.selectedRange.location
        var len = self.selectedRange.length
        
        let location = recognizer.locationInView(_endGrabber)
        
        if location.x <= _endGrabber.bounds.size.width / 2.0 {
            if len > 0 {
                if len != 1 {
                    len--
                }
            } else {
                if pos != 0 {
                    pos--
                }
            }
        } else {
            if len > 0 {
                if count(self.text) != pos + len {
                    len++
                }
            } else {
                if count(self.text) != pos + len {
                    pos++
                }
            }
        }
        
        self.selectedTextRange = self.textRangeFromPosition(self.positionFromPosition(self.beginningOfDocument, offset: pos), toPosition: self.positionFromPosition(self.beginningOfDocument, offset: pos + len))
        
        
        // Show editing menu
        self.showEditingMenu()
    }
    
    
    
    @objc private func startGrabberRepositioningTimerFired(timer: NSTimer) {
        // Invalidate timer
        _startGrabberRepositioningTimer?.invalidate()
        _startGrabberRepositioningTimer = nil
        
        
        // Snap start grabber
        self.snapStartGrabberTipPosition()
        _startGrabber.transform(animated: true)
        
    }
    
    
    
    @objc private func endGrabberRepositioningTimerFired(timer: NSTimer) {
        // Invalidate timer
        _endGrabberRepositioningTimer?.invalidate()
        _endGrabberRepositioningTimer = nil
        
        
        // Snap end grabber
        self.snapEndGrabberTipPosition()
        _endGrabber.transform(animated: true)
    }
    
    
    
    @objc private func startGrabberPanned(recognizer: UIPanGestureRecognizer) {
        self.hideEditingMenu()
        self.bringSubviewToFront(_startGrabber)
        
        _startGrabberIsBeingManipulated = true
        
        
        var animated = false
        
        // Began
        if recognizer.state == UIGestureRecognizerState.Began {
            _panOffset = recognizer.locationInView(_startGrabber)
            _panOffset.y = start_grabber_y_offset
            
            _startGrabber.forcedTipAlignment = .Center
            
            if !_startGrabber.extended {
                _startGrabber.extended = true
                animated = true
            }
        }
        
        
        // Always
        let location = recognizer.locationInView(self)
        let tip = CGPointMake(location.x - _panOffset.x + 0.5 * _startGrabber.frame.size.width,
                              location.y - _panOffset.y + 1.0 * _startGrabber.frame.size.height)
        _startGrabber.tipPosition = tip
        
        let pos = CGPointMake(tip.x, tip.y + start_grabber_tip_selection_offset)
        
        
        let textPosition = self.closestPositionToPoint(pos)
        let posOffset = self.offsetFromPosition(self.beginningOfDocument, toPosition: textPosition)
        let endOffset = self.offsetFromPosition(self.beginningOfDocument, toPosition: self.selectedTextRange!.end)
        
        if posOffset < endOffset {
            self.selectedTextRange = self.textRangeFromPosition(textPosition, toPosition: self.selectedTextRange!.end)
        }
        
        
        // Ended
        if recognizer.state == UIGestureRecognizerState.Ended {
            self.snapStartGrabberTipPosition()
            
            animated = true
            
            self.showEditingMenu()
        }
        
        
        // Transform
        _startGrabber.transform(animated: animated)
    }
    
    
    
    @objc private func endGrabberPanned(recognizer: UIPanGestureRecognizer) {
        self.hideEditingMenu()
        self.bringSubviewToFront(_endGrabber)
        
        _endGrabberIsBeingManipulated = true
        
        
        var animated = false
        
        // Began
        if recognizer.state == UIGestureRecognizerState.Began {
            _panOffset = recognizer.locationInView(_endGrabber)
            _panOffset.y = 0.7 * _endGrabber.frame.size.height
            
            _endGrabber.forcedTipAlignment = .Center
            
            if !_endGrabber.extended {
                _endGrabber.extended = true
                animated = true
            }
        }
        
        
        // Always
        let location = recognizer.locationInView(self)
        let tip = CGPointMake(location.x - _panOffset.x + 0.5 * _endGrabber.frame.size.width,
                              location.y - _panOffset.y)
        _endGrabber.tipPosition = tip
        
        let pos = CGPointMake(tip.x, tip.y - end_grabber_tip_selection_offset)
        
        let textPosition = self.closestPositionToPoint(pos)
        let posOffset = self.offsetFromPosition(self.beginningOfDocument, toPosition: textPosition)
        let startOffset = self.offsetFromPosition(self.beginningOfDocument, toPosition: self.selectedTextRange!.start)
        
        
        // Set selected range
        if !(self.selectedRange.length > 0 && posOffset <= startOffset) {
            if self.selectedRange.length == 0 {
                self.selectedTextRange = self.textRangeFromPosition(textPosition, toPosition: textPosition)
            } else {
                self.selectedTextRange = self.textRangeFromPosition(self.selectedTextRange?.start, toPosition: textPosition)
            }
        }
        
        
        // Ended
        if recognizer.state == UIGestureRecognizerState.Ended {
            self.snapEndGrabberTipPosition()
            
            animated = true
            
            self.showEditingMenu()
        }
        
        
        // Transform
        _endGrabber.transform(animated: animated)
    }
    
    
    
    private func snapStartGrabberTipPosition() {
        _startGrabber.forcedTipAlignment = nil
        _startGrabberIsBeingManipulated = false
        
        
        // Move start grabber to final position
        let topLeft = self.selectionCorners().0
        _startGrabber.tipPosition = topLeft
    }
    
    
    
    private func snapEndGrabberTipPosition() {
        _endGrabber.forcedTipAlignment = nil
        _endGrabberIsBeingManipulated = false
        
        
        // Move end grabber to final position
        let bottomRight = self.selectionCorners().1
        _endGrabber.tipPosition = bottomRight
    }
    
    
    
    
    
    
    
    // MARK: - UITextInput protocol
    
    override public func selectionRectsForRange(range: UITextRange) -> [AnyObject] {
        return []
    }
    
    
    
    
    
    
    
    // MARK: - UIResponder
    
    override public func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
        if action == "selectAll:" || action == "select:" {
            return false
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    
    
    
    
    
    
    // MARK: - Helpers
    
    private func showEditingMenu() {
        let menuController = UIMenuController.sharedMenuController()
        if !menuController.menuVisible {
            let rect = self.convertRect(_keyboardFrame, fromView: nil)
            menuController.setTargetRect(rect, inView: self)
            menuController.update()
            menuController.setMenuVisible(true, animated: false)
        }
    }
    
    
    
    private func hideEditingMenu() {
        let menuController = UIMenuController.sharedMenuController()
        if menuController.menuVisible {
            menuController.setMenuVisible(false, animated: false)
        }
    }
    
    
    
    private func distanceFrom(#point: CGPoint, toRect rect: CGRect) -> CGFloat {
        let center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect))
        let x2 = pow(fabs(center.x - point.x), 2)
        let y2 = pow(fabs(center.y - point.y), 2)
        return sqrt(x2 + y2)
    }
    
    
    
    private func selectionCorners() -> (CGPoint, CGPoint) {
        if self.selectedTextRange!.empty {
            let rect = self.caretRectForPosition(self.selectedTextRange!.start)
            
            return (rect.origin, CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height))
        }
        
        let rects: [UITextSelectionRect] = super.selectionRectsForRange(self.selectedTextRange!) as! [UITextSelectionRect]
        
        var topLeft = CGPointMake(CGFloat.max, CGFloat.max)
        var bottomRight = CGPointMake(CGFloat.min, CGFloat.min)
        for r in rects {
            if r.rect.size.width < 0.5 || r.rect.size.height < 0.5 {
                continue
            }
            
            if r.rect.origin.y < topLeft.y {
                topLeft.y = r.rect.origin.y
                topLeft.x = r.rect.origin.x
            }
            
            if r.rect.origin.y + r.rect.size.height > ceil(bottomRight.y) {
                bottomRight.y = r.rect.origin.y + r.rect.size.height
                bottomRight.x = r.rect.origin.x + r.rect.size.width
            }
        }
        
        return (topLeft, bottomRight)
    }
}
