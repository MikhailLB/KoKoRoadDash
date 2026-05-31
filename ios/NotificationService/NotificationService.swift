import FirebaseMessaging
import UserNotifications

/// Notification Service Extension — intercepts incoming pushes before iOS
/// displays them and asks Firebase Messaging to download and attach the
/// image specified in `fcm_options.image` (or `notification.image`).
///
/// Requirements for rich media to appear:
///   • Backend APS payload must include `"mutable-content": 1`
///   • FCM message must include an image URL (fcm_options.image)
///   • This extension must be installed and signed correctly
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

    Messaging.serviceExtension().populateNotificationContent(
      bestAttemptContent,
      withContentHandler: contentHandler
    )
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler,
       let bestAttemptContent = bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
