import Flutter
import UIKit
import GoogleMaps
import Stripe

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 🔥 Google Maps API key
    GMSServices.provideAPIKey("AIzaSyD0yiq58kkUZUe2ViSnmleGOxe9T5tPFTc")

    // 💳 Stripe publishable key (TEST MODE)
    StripeAPI.defaultPublishableKey = "pk_test_51TA7mDEF3hIooLTXxM34PAOAsfUUukr2zuHNzvbmdnmuomGC6dPpxXTuujpWuVz23CCwhsdm982edsFr9BMyqCMc00EkZZ4hvO"

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}