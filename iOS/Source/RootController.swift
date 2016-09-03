import UIKit
import Photos

class RootController: UIViewController {
    lazy var textView: UITextView = {
        let view = UITextView()
        view.textColor = .whiteColor()
        view.text = "Calculating MD5s..."
        view.backgroundColor = .blackColor()

        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.textView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.textView.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        self.textView.center = self.view.center
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        self.checkAuthorizationStatus { success in
            if success {
                self.displayHash()
            }
        }
    }

    func checkAuthorizationStatus(completion: (success: Bool) -> Void) {
        let currentStatus = PHPhotoLibrary.authorizationStatus()

        guard currentStatus != .Authorized else {
            completion(success: true)
            return
        }

        PHPhotoLibrary.requestAuthorization { authorizationStatus in
            dispatch_async(dispatch_get_main_queue(), {
                if authorizationStatus == .Denied {
                    completion(success: false)
                } else if authorizationStatus == .Authorized {
                    completion(success: true)
                }
            })
        }
    }

    func displayHash() {
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Video, options: fetchOptions)
        guard let asset = fetchResult.firstObject as? PHAsset else { fatalError("Drag sample.mov to your Simulator to add it to the Camera Roll") }

        let manager = PHCachingImageManager()
        let requestOptions = PHVideoRequestOptions()
        requestOptions.networkAccessAllowed = true
        requestOptions.version = .Original

        let resource = PHAssetResource.assetResourcesForAsset(asset).first!
        let filename = resource.originalFilename
        let pathToWrite = NSTemporaryDirectory().stringByAppendingString(filename)
        let destinationURL = NSURL.fileURLWithPath(pathToWrite)
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(pathToWrite) {
            print("File already exists")
            try! fileManager.removeItemAtPath(pathToWrite)
        }

        let _ = manager.requestExportSessionForVideo(asset, options: requestOptions, exportPreset: AVAssetExportPresetHighestQuality) { exportSession, info in
            print("requestExport info: \(info!)")
            guard let exportSession = exportSession else { fatalError("Couldn't create exporter with  \(asset)") }
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = AVFileTypeQuickTimeMovie
            exportSession.exportAsynchronouslyWithCompletionHandler {
                switch exportSession.status {
                case .Unknown: print("status: Unknown")
                case .Waiting: print("status: Waiting")
                case .Exporting: print("status: Exporting")
                case .Completed: print("status: Completed")
                case .Failed: print("status: Failed")
                case .Cancelled: print("status: Cancelled")
                }

                let exportedData = NSData(contentsOfURL: destinationURL)!
                let url = NSBundle.mainBundle().URLForResource("sample", withExtension: "mov")!
                let localData = NSData(contentsOfURL: url)!
                let localHash = localData.md5Hash()
                let exportedHash = exportedData.md5Hash()

                dispatch_async(dispatch_get_main_queue()) {
                    self.textView.text = "Expected: \(localHash)\nGot         : \(exportedHash)\n \nExpected MD5 verified using http://onlinemd5.com"
                }
            }
        }
    }
}