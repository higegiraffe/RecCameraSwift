//
//  LiveView.swift
//  RecCameraSwift
//
//  Created by haruhito on 2015/04/12.
//  Copyright (c) 2015年 FromF. All rights reserved.
//

import UIKit
import AVFoundation

class LiveView: UIViewController , OLYCameraLiveViewDelegate , OLYCameraRecordingSupportsDelegate , AVCaptureVideoDataOutputSampleBufferDelegate{
    @IBOutlet weak var liveViewImage: UIImageView!
    @IBOutlet weak var recviewImage: UIImageView!
    @IBOutlet weak var infomation: UILabel!

    //顔認識用のsecretView
    var secretView: UIImageView!

    //顔認識関連の定義
    var onlyFireNotificatonOnStatusChange : Bool = true
    var leftEyeClosed : Bool?
    var rightEyeClosed : Bool?
    var isWinking : Bool?
    var isBlinking : Bool?
    var faceDetected : Bool?
    
    let notificationCenter : NSNotificationCenter = NSNotificationCenter.defaultCenter()
    let LeftEyeClosedNotification = NSNotification(name: "LeftEyeClosedNotification", object: nil)
    let RightEyeClosedNotification = NSNotification(name: "RightEyeClosedNotification", object: nil)
    let LeftEyeOpenNotification = NSNotification(name: "LeftEyeOpenNotification", object: nil)
    let RightEyeOpenNotification = NSNotification(name: "RightEyeOpenNotification", object: nil)
    let WinkingNotification = NSNotification(name: "WinkingNotification", object: nil)
    let NotWinkingNotification = NSNotification(name: "NotWinkingNotification", object: nil)
    let BlinkingNotification = NSNotification(name: "BlinkingNotification", object: nil)
    let NotBlinkingNotification = NSNotification(name: "NotBlinkingNotification", object: nil)
    let NoFaceDetectedNotification = NSNotification(name: "NoFaceDetectedNotification", object: nil)
    let FaceDetectedNotification = NSNotification(name: "FaceDetectedNotification", object: nil)
    
    let emojiLabel : UILabel = UILabel(frame: UIScreen.mainScreen().bounds)
    
    //AppDelegate instance
    var appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //Notification Regist
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "NotificationApplicationBackground:", name: UIApplicationDidEnterBackgroundNotification , object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "NotificationCameraKitDisconnect:", name: appDelegate.NotificationCameraKitDisconnect as String, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "NotificationRechabilityDisconnect:", name: appDelegate.NotificationNetworkDisconnected as String, object: nil)

        let camera = AppDelegate.sharedCamera
        camera.liveViewDelegate = self
        camera.recordingSupportsDelegate = self
        
        camera.connect(OLYCameraConnectionTypeWiFi, error: nil)
        
        if (camera.connected) {
            camera.changeRunMode(OLYCameraRunModeRecording, error: nil)
            camera.changeLiveViewSize(OLYCameraLiveViewSizeXGA, error: nil)
            camera.setCameraPropertyValue("TAKEMODE", value: "<TAKEMODE/P>", error: nil)
            
            //顔認識関連の関数
            detectFaces()
            
            //顔認識の状態表示
            emojiLabel.text = "💤"
            emojiLabel.font = UIFont.systemFontOfSize(50)
            emojiLabel.textAlignment = .Center
            self.view.addSubview(emojiLabel)
            
            //顔認識時の処理
            NSNotificationCenter.defaultCenter().addObserverForName("FaceDetectedNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
                //顔認識の状態表示
                self.emojiLabel.text = "😊"
                
                //ウインクでレリーズ
                    if (self.isWinking == true) {
                        let camera = AppDelegate.sharedCamera
                        camera.takePicture(nil, progressHandler: nil, completionHandler: nil, errorHandler: nil)
                    }
                    return
            })
            
            //非顔認識時の処理
            NSNotificationCenter.defaultCenter().addObserverForName("NoFaceDetectedNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
                    self.emojiLabel.text = "💤"
            })
            
            //let inquire = camera.inquireHardwareInformation(nil) as NSDictionary
            //let modelname = inquire.objectForKey(OLYCameraHardwareInformationCameraModelNameKey) as? String
            //let version = inquire.objectForKey(OLYCameraHardwareInformationCameraFirmwareVersionKey) as? String
            //infomation.text = modelname! + " Ver." + version!
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        let camera = AppDelegate.sharedCamera

        camera.disconnectWithPowerOff(false, error: nil)
        
    }
    
    // セッション
    var mySession : AVCaptureSession!
    // カメラデバイス
    var myDevice : AVCaptureDevice!
    // 出力先
    var myOutput : AVCaptureVideoDataOutput!
    
    func detectFaces() {
        //secretViewの生成
        initDisplay()
        
        // カメラを準備
        if initCamera() {
        // 撮影開始
        mySession.startRunning()
            
        }
        
    }
        
    // secretViewの生成処理
    func initDisplay() {
        //スクリーンの幅
        let screenWidth = UIScreen.mainScreen().bounds.size.width;
        //スクリーンの高さ
        let screenHeight = UIScreen.mainScreen().bounds.size.height;
        
        secretView = UIImageView(frame: CGRectMake(0.0, 0.0, screenWidth, screenHeight))
        
    }
    
    // カメラの準備処理
    func initCamera() -> Bool {
        // セッションの作成.
        mySession = AVCaptureSession()
        
        // 解像度の指定.
        mySession.sessionPreset = AVCaptureSessionPresetMedium
        
        
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()
        
        // フロントカメラをmyDeviceに格納.
        for device in devices {
            if(device.position == AVCaptureDevicePosition.Front){
                myDevice = device as! AVCaptureDevice
            }
        }
        if myDevice == nil {
            return false
        }
        
        // フロントカメラからVideoInputを取得.
        let myInput = AVCaptureDeviceInput.deviceInputWithDevice(myDevice, error: nil) as! AVCaptureDeviceInput
        
        
        // セッションに追加.
        if mySession.canAddInput(myInput) {
            mySession.addInput(myInput)
        } else {
            return false
        }
        
        // 出力先を設定
        myOutput = AVCaptureVideoDataOutput()
        myOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA ]
        
        // FPSを設定
        var lockError: NSError?
        if myDevice.lockForConfiguration(&lockError) {
            if let error = lockError {
                println("lock error: \(error.localizedDescription)")
                return false
            } else {
                myDevice.activeVideoMinFrameDuration = CMTimeMake(1, 15)
                myDevice.unlockForConfiguration()
            }
        }
        
        // デリゲートを設定
        let facequeue: dispatch_queue_t = dispatch_queue_create("myqueue",  nil)
        myOutput.setSampleBufferDelegate(self, queue: facequeue)

        
        
        // 遅れてきたフレームは無視する
        myOutput.alwaysDiscardsLateVideoFrames = true
        
        
        // セッションに追加.
        if mySession.canAddOutput(myOutput) {
            mySession.addOutput(myOutput)
        } else {
            return false
        }
        
        // カメラの向きを合わせる
        for connection in myOutput.connections {
            if let conn = connection as? AVCaptureConnection {
                if conn.supportsVideoOrientation {
                    conn.videoOrientation = AVCaptureVideoOrientation.Portrait
                }
            }
        }
        
        return true
    }
    
    // 毎フレーム実行される処理
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        var q_global: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        var q_main: dispatch_queue_t  = dispatch_get_main_queue()
        
        dispatch_async(q_global, {
            dispatch_async(q_main, {
                
                // UIImageへ変換して表示させる
                //imageView.image = CameraUtil.imageFromSampleBuffer(sampleBuffer)
                
                return
            })
            
            // UIImageへ変換
            let image = CameraUtil.imageFromSampleBuffer(sampleBuffer)
            
            // 顔認識
            let detectFace = detector.recognizeFace(image)
                
            // 検出された顔のデータをCIFaceFeatureで処理
            
            if (detectFace.faces.count != 0) {
                if (self.onlyFireNotificatonOnStatusChange == true) {
                    if (self.faceDetected == false) {
                        self.notificationCenter.postNotification(self.FaceDetectedNotification)
                    }
                } else {
                    self.notificationCenter.postNotification(self.FaceDetectedNotification)
                }
                self.faceDetected = true
                
                for feature in detectFace.faces {
                    var faceBounds : CGRect = feature.bounds
                    
                    if ((feature.hasLeftEyePosition) != nil) {
                        var leftEyePosition : CGPoint = feature.leftEyePosition
                    }
                    
                    if ((feature.hasRightEyePosition) != nil) {
                        var rightEyePosition : CGPoint = feature.rightEyePosition
                    }
                
                    if ((feature.hasMouthPosition) != nil) {
                        var mouthPosition : CGPoint = feature.mouthPosition
                    }
                    if (((feature.leftEyeClosed) != nil) || ((feature.rightEyeClosed) != nil)) {
                        if (self.onlyFireNotificatonOnStatusChange == true) {
                            if (self.isWinking == false) {
                                self.notificationCenter.postNotification(self.WinkingNotification)
                            }
                        } else {
                            self.notificationCenter.postNotification(self.WinkingNotification)
                        }
                        self.isWinking = true
                        
                        if ((feature.leftEyeClosed) != nil) {
                            if (self.onlyFireNotificatonOnStatusChange == true) {
                                if (self.leftEyeClosed == false) {
                                    self.notificationCenter.postNotification(self.LeftEyeClosedNotification)
                                }
                            } else {
                                self.notificationCenter.postNotification(self.LeftEyeClosedNotification)
                            }
                            self.leftEyeClosed = true
                        }
                        
                        if ((feature.rightEyeClosed) != nil) {
                            if (self.onlyFireNotificatonOnStatusChange == true) {
                                if (self.rightEyeClosed == false) {
                                    self.notificationCenter.postNotification(self.RightEyeClosedNotification)
                                }
                            } else {
                                self.notificationCenter.postNotification(self.RightEyeClosedNotification)
                            }
                            self.rightEyeClosed = true
                        }
                        
                        if (((feature.leftEyeClosed) != nil) && ((feature.rightEyeClosed) != nil )) {
                            if (self.onlyFireNotificatonOnStatusChange == true) {
                                if (self.isBlinking == false) {
                                    self.notificationCenter.postNotification(self.BlinkingNotification)
                                }
                            } else {
                                self.notificationCenter.postNotification(self.BlinkingNotification)
                            }
                            self.isBlinking = true
                        }
                    } else {
                        if (self.onlyFireNotificatonOnStatusChange == true) {
                            if (self.isBlinking == true) {
                                self.notificationCenter.postNotification(self.NotBlinkingNotification)
                            }
                            if (self.isWinking == true) {
                                self.notificationCenter.postNotification(self.NotWinkingNotification)
                            }
                            if (self.rightEyeClosed == true) {
                                self.notificationCenter.postNotification(self.RightEyeOpenNotification)
                            }
                            if (self.leftEyeClosed == true) {
                                self.notificationCenter.postNotification(self.LeftEyeOpenNotification)
                            }
                        } else {
                            self.notificationCenter.postNotification(self.NotBlinkingNotification)
                            self.notificationCenter.postNotification(self.NotWinkingNotification)
                            self.notificationCenter.postNotification(self.LeftEyeOpenNotification)
                            self.notificationCenter.postNotification(self.RightEyeOpenNotification)
                        }
                        self.isBlinking = false
                        self.isWinking = false
                        self.leftEyeClosed = feature.leftEyeClosed
                        self.rightEyeClosed = feature.rightEyeClosed
                    }
                }
            } else {
                if (self.onlyFireNotificatonOnStatusChange == true) {
                    if (self.faceDetected == true) {
                        self.notificationCenter.postNotification(self.NoFaceDetectedNotification)
                    }
                } else {
                    self.notificationCenter.postNotification(self.NoFaceDetectedNotification)
                }
                self.faceDetected = false
            }
            
        })
        return
        
    }
    
    // MARK: - Button Action
    @IBAction func shutterButtonAction(sender: AnyObject) {
        let camera = AppDelegate.sharedCamera
        
        camera.takePicture(nil, progressHandler: nil, completionHandler: nil, errorHandler: nil)    
    }
    
    // MARK: - 露出補正
    @IBAction func exprevSlider(sender: AnyObject) {
        let slider = sender as! UISlider
        let index = Int(slider.value + 0.5)
        slider.value = Float(index)
        
        var value = NSString(format: "%+0.1f" , slider.value)
        if (slider.value == 0) {
            value = NSString(format: "%0.1f" , slider.value)
        }
        
        let camera = AppDelegate.sharedCamera

        camera.setCameraPropertyValue("EXPREV", value: "<EXPREV/" + (value as String) + ">", error: nil)
        
    }
    
    // MARK: - LiveView Update
    func camera(camera: OLYCamera!, didUpdateLiveView data: NSData!, metadata: [NSObject : AnyObject]!) {
        let image : UIImage = OLYCameraConvertDataToImage(data,metadata)
        self.liveViewImage.image = image
    }
    
    // MARK: - Recview
    func camera(camera: OLYCamera!, didReceiveCapturedImagePreview data: NSData!, metadata: [NSObject : AnyObject]!) {
        let image : UIImage = OLYCameraConvertDataToImage(data,metadata)
        recviewImage.image = image
    }
    
    // MARK: - Notification
    func NotificationApplicationBackground(notification : NSNotification?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    func NotificationCameraKitDisconnect(notification : NSNotification?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    func NotificationRechabilityDisconnect(notification : NSNotification?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
