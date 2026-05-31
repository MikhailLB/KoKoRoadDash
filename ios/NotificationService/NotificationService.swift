import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Notification Service Extension — gives FCM a chance to download and
/// attach rich media (images) to the push payload BEFORE iOS displays it,
/// even when the host app is killed.
///
/// Backend must include `"mutable-content": 1` in the `aps` payload or
/// iOS will not invoke this extension. Without media attachment, images
/// only appear when the Dart isolate is alive at delivery time.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      request.content.mutableCopy() as? UNMutableNotificationContent

    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(
      bestAttemptContent,
      withContentHandler: contentHandler
    )
    #else
    contentHandler(bestAttemptContent)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler,
       let bestAttemptContent = bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
