//
//  detector.swift
//  RecCameraSwift
//
//  Created by yuki on 2015/08/09.
//  Copyright (c) 2015年 FromF. All rights reserved.
//

import UIKit
import CoreImage

var DeviceOrientation: UIDeviceOrientation = UIDevice.currentDevice().orientation

class detector {
    class func recognizeFace(image: UIImage,orientation: Int) -> (faces: NSArray , transform: CGAffineTransform) {
    
        println("detctor orientation")
        println(orientation)
        
        // NSDictionary型のoptionを生成。顔認識の精度を追加する.
        var options : NSDictionary = [CIDetectorSmile : true, CIDetectorEyeBlink : true, CIDetectorImageOrientation :orientation]
        //var options : NSDictionary = [CIDetectorSmile : true, CIDetectorEyeBlink : true]
        
        // CIDetectorを生成。顔認識をするのでTypeはCIDetectorTypeFace.
        let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        //コントラスト強調
        var outputImage :CIImage = CIImage(image: image)
        let ciFilter : CIFilter = CIFilter(name: "CIToneCurve")
        ciFilter.setValue(outputImage, forKey: kCIInputImageKey)
        ciFilter.setValue(CIVector(x: 0.0, y: 0.0), forKey: "inputPoint0")
        ciFilter.setValue(CIVector(x: 0.25, y: 0.1), forKey: "inputPoint1")
        ciFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
        ciFilter.setValue(CIVector(x: 0.75, y: 0.9), forKey: "inputPoint3")
        ciFilter.setValue(CIVector(x: 1.0, y: 1.0), forKey: "inputPoint4")
        var outputImage2 :CIImage = ciFilter.outputImage
        //アンシャープマスク
        let mySharpFilter = CIFilter(name:"CIUnsharpMask")
        mySharpFilter.setValue(outputImage2, forKey: kCIInputImageKey)
        var outputImage3 : CIImage = mySharpFilter.outputImage
        
        // detectorで認識した顔のデータを入れておくNSArray.
        var faces : NSArray = detector.featuresInImage(outputImage3, options: options as [NSObject : AnyObject]) as! [CIFeature]
        
        // UIKitは画面左上に原点があるが、CoreImageは画面左下に原点があるのでそれを揃えなくてはならない.
        // CoreImageとUIKitの原点を画面左上に統一する処理.
        var transform : CGAffineTransform = CGAffineTransformMakeScale(1, -1)
        //       transform = CGAffineTransformTranslate(transform, 0, -self.imageView.bounds.size.height)
        transform = CGAffineTransformTranslate(transform, 0, -UIScreen.mainScreen().bounds.size.height)
        
        return (faces,transform)
        
    }
    
}
