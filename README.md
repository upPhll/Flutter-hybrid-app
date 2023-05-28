# Flutter-hybrid-app
A template for a cross-platform hybrid app in Flutter (Android and iOS)

If you decided to build a website and now want to offer it packaged as an app too, this is for you. A year ago, I developed a cross-platform hybrid app in Flutter myself. To save you the effort, I share the result here.

Hybrid apps are a very efficient alternative to native apps. They basically use the browser engine of your operating system to load only one mobile-optimized website, yours. Since you're checking out this page, I'm almost certain you already know about the benefits of hybrid apps, so let's get right to it.


## To get a quick first impression
This video shows the behaviour of the template when opening the app and the transitions when loading different pages:

https://github.com/upPhll/Flutter-hybrid-app/assets/115892491/17708069-3eb2-49e1-a03b-1f95d04c3211

or

1. Check out the app 'bindint' in the Play or App Store.

2. Create a new Flutter project, copy the main.dart and pubspec.yaml, change all "example.com" in the main.dart to your website and run the app.

## What to expect

This app includes:

- Push Notifications
- Cookie Management (for sessions, to stay logged in)
- Camera Usage
- Device Detection (iOS, Android / phone, tablet)
- Orientation Control (only portrait up on phones)
- Load Progress Indicator Bar
- Offline Handling (show “No internet connection” site)
- Redirection to browser app for other websites

## Details

This is interesting if you decided to build on this template.

The app is based on the InAppWebView library to load websites like a browser. It is by far the best working one for Flutter.

The code is only in the main.dart. For iOS there is another main.dart with some changes like the color of the bottom and header bar, but else very alike. The code is relative manageable. Thus I only explain important points regarding the core functions listed above.

To send push notifications towards a specific logged in app user, we send the token ID of our firebase instance as cookie if we open the /login, /register or /logout URL. This way we can keep track on the server which token ID belongs currently to which user.

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L134)

To open a specific URL in the webview when the user starts the app by clicking a push notification, the *types* attribute of the notification can be used. This is done exemplary in setupInteractedMessage().

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L98)

To allow only portrait up orientation mode on phones, the current operating system has to be known. Since the way to retrieve the isTablet information is different for iOS and Android.

[Code Link Device Orientation](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L311)

[Code Link Get isTablet](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L188)

The LinearProgressIndicator is used to avoid an app that seems hung on a bad internet connection. Problematic is only, once activated, the app has to be restarted to turn it off. Thus it is only activated if a page load takes more than 800ms. Otherwise the flashing progress bar with a good connection would be quite annoying. The bar is controlled with the value of the progress variable.

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L358)

If the user tries to load a page without an internet connection, there shouldn't show up a default browser no internet page. This is managed in the onLoadError function, which instead displays the HTML code of a no connection info site. I tried for half an hour to put the HTML code into a separate file, but finally gave up and left it in the main.dart.

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L413)

The redirection to the default browser is done at the beginning of the onLoadStart function.

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L322)

The permission procedure for camera access is also a bit different on the operating systems. Just search for “permission” in the according file and check the code.

The _onWillPop function is taking care of going one site back in the webview when the Android navigation button is touched.

[Code Link](https://github.com/upPhll/Flutter-hybrid-app/blob/main/android/main.dart#L85)

Search for tutorials to see how the launcher icon of the app can be configured. One detail I could not resolve was the short appearing white screen after the launcher icon was shown.
