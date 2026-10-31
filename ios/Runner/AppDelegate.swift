import Flutter
import UIKit
import QuickLook
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, QLPreviewControllerDataSource {
  private var documentURL: URL?
  private var privacyCover: UIView?
  private var reportProtected=false
  private var nativeChannel:FlutterMethodChannel?
  private var pendingNotificationAction:[String:Any]?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate=self
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "app.schoolday.schoolerp.sync")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func numberOfPreviewItems(in controller:QLPreviewController)->Int {documentURL == nil ? 0:1}
  func previewController(_ controller:QLPreviewController,previewItemAt index:Int)->QLPreviewItem {documentURL! as NSURL}
  @objc private func hideReport(){
    guard reportProtected else{return}
    let window=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first{$0.isKeyWindow}
    let cover=UIView(frame:window?.bounds ?? .zero);cover.backgroundColor=UIColor.systemBackground;window?.addSubview(cover);privacyCover=cover
  }
  @objc private func showReport(){privacyCover?.removeFromSuperview();privacyCover=nil}
  override func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping()->Void){
    let info=response.notification.request.content.userInfo
    if response.actionIdentifier=="approve",info["type"] as? String=="leave",info["approve"] as? String=="true",let entity=info["entity_id"] as? String,let school=info["school_id"] as? String {
      let action:[String:Any]=["type":"leave","action":"approve","approve":"true","entity_id":entity,"school_id":school,"event_id":info["event_id"] as? String ?? entity]
      DispatchQueue.main.async {self.pendingNotificationAction=action;self.nativeChannel?.invokeMethod("notificationAction",arguments:action);completionHandler()}
      return
    }
    super.userNotificationCenter(center,didReceive:response,withCompletionHandler:completionHandler)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar=engineBridge.pluginRegistry.registrar(forPlugin: "SchooldayNative")!
    let channel=FlutterMethodChannel(name: "schoolday/native", binaryMessenger:registrar.messenger())
    nativeChannel=channel
    channel.setMethodCallHandler { [weak self] call,result in
      guard let self=self else {return}
      let args=call.arguments as? [String:Any] ?? [:]
      if call.method=="takeNotificationAction" {let action=self.pendingNotificationAction;self.pendingNotificationAction=nil;result(action);return}
      if call.method=="deviceInfo" {result(["timezone":TimeZone.current.identifier,"low_ram":ProcessInfo.processInfo.physicalMemory<=3*1024*1024*1024]);return}
      if call.method=="protectReport" {self.reportProtected=args["enabled"] as? Bool ?? false;result(nil);return}
      if call.method=="openFile",let path=args["path"] as? String {
        let url=URL(fileURLWithPath:path).standardizedFileURL.resolvingSymlinksInPath()
        let roots=[FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!,FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first!]
        guard roots.contains(where:{url.path.hasPrefix($0.path+"/")}),FileManager.default.fileExists(atPath:url.path) else {result(FlutterError(code:"file_access",message:"Document unavailable",details:nil));return}
        self.documentURL=url;let preview=QLPreviewController();preview.dataSource=self
        let root=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first{$0.isKeyWindow}?.rootViewController
        var presenter=root;while let next=presenter?.presentedViewController {presenter=next};presenter?.present(preview,animated:true);result(nil);return
      }
      result(FlutterMethodNotImplemented)
    }
    NotificationCenter.default.addObserver(self,selector:#selector(hideReport),name:UIApplication.willResignActiveNotification,object:nil)
    NotificationCenter.default.addObserver(self,selector:#selector(showReport),name:UIApplication.didBecomeActiveNotification,object:nil)
  }
}
