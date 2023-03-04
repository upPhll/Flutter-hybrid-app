import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

// for push notifications
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// only only portrait mode
import 'package:flutter/services.dart';

// for camera permission
import 'package:permission_handler/permission_handler.dart';

// to distinguish between iphone and ipad
import 'package:device_info_plus/device_info_plus.dart';


Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // for camera permission (profile picture)
  await Permission.camera.request();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // change the android navigation bar color
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xfffb5137),
  ));

  runApp(const MyApp());
}



class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}



class _MyAppState extends State<MyApp> {

  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        verticalScrollBarEnabled: false,
        applicationNameForUserAgent: 'mobile_App', // Agent info
        cacheEnabled: true,
        clearCache: false, // avoid to reload media files on every appstart
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  bool loadTimerover = false;
  late Timer loadbartimer;

  CookieManager cookieManager = CookieManager.instance();
  final cookieurl = Uri.parse("https://www.example.com/");

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final urlController = TextEditingController();

  // to go one site back when device button is clicked
  Future<bool> _onWillPop(BuildContext context) async {
    // the ! is required to ignore null cases
    if (await webViewController!.canGoBack()) {
      webViewController?.goBack();
      // deactivates the default back button handler, which closes the app
      return Future.value(false);
    } else {
      // close the app
      return Future.value(true);
    }
  }

  // this is called at the end of the InAppWebview Init to handle notif interactions
  Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a terminated state
    RemoteMessage? initialMessage =
    await _firebaseMessaging.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    // replacement method for onLaunch and onResume !
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // onMessageOpenedApp and getInitialMessage do the same
    // both are configured to make UI as smooth as possible
  }

  void _handleMessage(RemoteMessage message) {

    if (message.data['type'] == 'chat') {
      webViewController?.loadUrl(
          urlRequest: URLRequest(url: Uri.parse("https://www.example.com/chats/")));
    }
    if (message.data['type'] == 'verify') {
      webViewController?.loadUrl(
          urlRequest: URLRequest(url: Uri.parse("https://www.example.com/settings/profile/")));
    }
  }


  // set the fcm token for push notifications as secured cookie for the server
  // server is using the cookie on login and logout to manage all user tokens
  void setTokenCookie() async {
    // wait for the url to load, take the cookie and set it as token
    //final expiresDate = DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch;
    String? fetchToken = await _firebaseMessaging.getToken();
    final cookieurlLogin = Uri.parse("https://www.example.com/login/");
    if (fetchToken != null) {
      await cookieManager.setCookie(
        url: cookieurlLogin,
        name: "notifID_login",        // check the cookie name in a web inspector of a browser
        value: fetchToken.toString(),
        domain: ".example.com",       // host to which the cookie will be send
        //expiresDate: expiresDate,
        path: "/login",               // path that must exist in the requested url

        // for the browser to send the cookie header
        isSecure: true,               // cookie is only send with https
        isHttpOnly: true,             // forbids JS from accessing the cookie
        sameSite: HTTPCookieSameSitePolicy.LAX,  // cookie is not send on cross-site requests
      );

      final cookieurlLogout = Uri.parse("https://www.example.com/logout/");
      await cookieManager.setCookie(
        url: cookieurlLogout,
        name: "notifID_logout",
        value: fetchToken.toString(),
        domain: ".example.com",       // host to which the cookie will be send
        //expiresDate: expiresDate,
        path: "/logout",               // path that must exist in the requested url

        // for the browser to send the cookie header
        isSecure: true,               // cookie is only send with https
        isHttpOnly: true,             // forbids JS from accessing the cookie
        sameSite: HTTPCookieSameSitePolicy.LAX,  // cookie is not send on cross-site requests
      );

      final cookieurlRegister = Uri.parse("https://www.example.com/register/");
      await cookieManager.setCookie(
        url: cookieurlRegister,
        name: "notifID_register",
        value: fetchToken.toString(),
        domain: ".example.com",       // host to which the cookie will be send
        //expiresDate: expiresDate,
        path: "/register",            // path that must exist in the requested url

        // for the browser to send the cookie header
        isSecure: true,               // cookie is only send with https
        isHttpOnly: true,             // forbids JS from accessing the cookie
        sameSite: HTTPCookieSameSitePolicy.LAX,  // cookie is not send on cross-site requests
      );
    }
    //{expiresDate: null, isSessionOnly: null, }
  }

  // checks if Android or iOS and than checks if tablet or ipad
  Future<bool> deviceIsTablet(BuildContext context) async{
    bool isTablet = false;
    bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    bool isAndroid = Theme.of(context).platform == TargetPlatform.android;

    if (isAndroid){
      var shortestSide = MediaQuery.of(context) .size.shortestSide;
      // Determine if we should use mobile layout or not, 600 here is
      // a common breakpoint for a typical 7-inch tablet.
      final bool useMobileLayout = shortestSide > 550;
      isTablet = useMobileLayout;
    }
    if (isIOS){
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      IosDeviceInfo info = await deviceInfo.iosInfo;
      // check for NullSafety
      var modelInfo = info.model;
      modelInfo ??= "";  // quick way for: if (modelInfo == null) modelInfo = "";

      if (modelInfo.toLowerCase().contains("ipad")) {
        isTablet = true;
      }
    }

    return isTablet;
  }


  // sets preferred device orientation upwards IF device is a smartphone
  void setOrientation(BuildContext context) async {
    bool isTablet = await deviceIsTablet(context);
    if (isTablet == false) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }


  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: const Color(0xfffb5137),
      ),
      // different commands per OS for reloading current url
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'example',
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.light,
        primaryColor: const Color(0xfffb5137),

        // Define the default font family.
        fontFamily: 'Georgia',

        // Define the default `TextTheme`. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more
        // (basically not needed for a real hybrid app)
        textTheme: const TextTheme(
          headline1: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
          headline6: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
          bodyText2: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
        ),
      ),
      // WillPopScope catches clicks on the device back-button on Android
      home: WillPopScope(
          onWillPop: () => _onWillPop(context),
          child: Scaffold(
              // settings for a invisible app bar
              appBar: PreferredSize(
                    preferredSize: const Size.fromHeight( 0.0), // here the desired height
                    child: AppBar(
                      elevation: 0, // to remove the shadow
                      backgroundColor: const Color(0xfffb5137),
                      systemOverlayStyle: SystemUiOverlayStyle.light, // status bar brightness
                    ),
                ),

                // SafeArea to avoid padding problems
                body: SafeArea(
                      child: Column(children: <Widget>[
                        Expanded(
                          child: Stack(
                            children: [
                              // Builder Wrapper for InAppWebView needed to make MaterialApp Context available
                              Builder(builder: (BuildContext context) { return InAppWebView(
                                key: webViewKey,
                                initialUrlRequest:
                                URLRequest(url: Uri.parse("https://www.example.com/")),
                                initialOptions: options,
                                pullToRefreshController: pullToRefreshController,
                                onWebViewCreated: (controller) async {
                                  webViewController = controller;
                                  // to ensure that the timer is at least running once after the app started
                                  loadTimerover = false;

                                  setTokenCookie();

                                  setupInteractedMessage();

                                  // to allow only portraitUp on Phones but all portrait modes on tablets
                                  setOrientation(context);
                                },

                                // redirect users to browser if they leave the specified domain
                                onLoadStart: (controller, url) async {
                                  // check if the url has the example domain
                                  // redirects to browser if not
                                  String newurl = url.toString();

                                  // used to determine if user loads external link
                                  // or example domain / "no internet html" path
                                  bool redirectToBrowser = true;
                                  var allowed = ["example.com", "about:blank"];
                                  for (final item in allowed) {
                                    if (newurl.contains(item)){
                                      redirectToBrowser = false;
                                    }
                                  }

                                  if (redirectToBrowser){
                                    // open the link in the default browser
                                    await launch(
                                        newurl,
                                        forceSafariVC: false,
                                        forceWebView: false,
                                    );
                                    // stop current loading process
                                    webViewController?.stopLoading();

                                    // reload current site
                                    webViewController?.goBack();
                                  }

                                  setState(() {
                                    this.url = url.toString();
                                    urlController.text = this.url;
                                  });

                                  /*
                                  Since there is no good load bar solution yet,
                                  this app has a load timer which is stopped and reset
                                  if the url was loaded fast enough; if the timer
                                  is over, a variable is switched to display the
                                  loadbar on every new side load. Once the loadbar
                                  is activated it cant be turned off, only per
                                  app restart. This solution is a compromise.
                                  */
                                  if (loadTimerover == false) {
                                    loadbartimer = Timer(
                                      //Duration(milliseconds: 0), set_loadTimeover());
                                        const Duration(milliseconds: 800), () {
                                      setState(() {
                                        loadTimerover = true;

                                        progress = 15 / 100;
                                        urlController.text = this.url;
                                      });
                                    }
                                    );
                                  }
                                },


                                onLoadStop: (controller, url) async {
                                  pullToRefreshController.endRefreshing();
                                  setState(() {
                                    this.url = url.toString();
                                    urlController.text = this.url;
                                  });
                                  // stop the loadtimer if it is not already stopped
                                  try {
                                    loadbartimer.cancel();
                                  }catch(e) {
                                    // empty catch, because the tryblock is only used
                                    // to kill the loadbartimer IF one exists
                                  }
                                },


                                onProgressChanged: (controller, progress) {
                                  // to show load progress only if it takes longer
                                  // than one second
                                  if (loadTimerover == true) {
                                    if (progress == 100) {
                                      pullToRefreshController.endRefreshing();
                                      /*
                                      here loadTimerover var is not reset because
                                      this section is run every time onProgressChanged
                                      is executed during the loadprocess, the loadbar
                                      would be stuck in one position
                                      */
                                    }

                                    setState(() {
                                      this.progress = progress / 100;
                                      urlController.text = url;
                                    });
                                  }

                                },


                                onLoadError: (controller, url, code, message) async {
                                  // stop the loadtimer if it is not already
                                  try {
                                    loadbartimer.cancel();
                                  }catch(e) {
                                    // empty catch because the tryblock is only used
                                    // to kill the loadbartimer IF one exists
                                  }

                                  // maybe the user has good internet after new connection is established
                                  loadTimerover = false;

                                  // HTML file to display in the app if no internet connection is available
                                  controller.loadData(data: """
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0,maximum-scale=1.0, user-scalable=no">
    <link rel="stylesheet" type="text/css" href="/static/css/fonts/fonts_with_their_licenses.css">
    <style>
    .bodycss{
      height: auto;
      background-color: #fb5137;
      color: #fffffa;
      font-family: 'robotoregular', sans-serif;
      font-size: 1.2em;
    }
    .maindiv{
      width: 80%;
      text-align: center;
      margin: 38vh auto 0 auto;
    }
    .header{
      font-size: 1.4em;
      font-weight: bold;
    }
    .infotext{
      margin: 11px 0;
    }
    .linkdiv{
      margin: 110px auto 0 auto;
      width: 156px;
    }
    .reloadlink{
      display: flex;
      justify-content: space-between;
      width: 120	px;
      height: 23px;
      background-color: Grey;
      vertical-align: middle;
      border: none;
      border-radius: 2px;
      font-size: 0.9em;
      font-weight: bold;
      text-decoration: none; 
      color: #fffffa;
      padding: 11px 18px;
      text-align: center;
      text-decoration: none;
      text-shadow: 0.5px 0.5px 1px rgb(0 0 0 / 20%);
      box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.2);
      -webkit-tap-highlight-color: transparent;
      
      transition: height 1.8s ease-in-out;
      -webkit-transition: height 1.8s ease-in-out;
      -moz-transition: height 1.8s ease-in-out;
      
    }
     .reloadlink:hover, .reloadlink:active{
       background-color: #a6a6a6
    }
    .reloadtext{
      margin: 2px 0;
      
    }
    </style>
  </head>
  <body class="bodycss">
    <div class="maindiv">
      <div>
        <p class="header">Connect to the Internet</P>
        <p class="infotext">You are offline. Check your connection.</p>
      </div>
      <div class="linkdiv">
        <a href='$url' class="reloadlink">
        
        <svg class="arrow" width="22px" height="22px" viewBox="0 0 135.9608 120" id="svg5">
  <sodipodi:namedview
     id="namedview7"
     pagecolor="#ffffff"
     bordercolor="#666666"
     borderopacity="1.0"
     showgrid="false" />
    <clipPath
       clipPathUnits="userSpaceOnUse"
       id="clipPath54">
      <path
         id="path56"
         style="display:none;fill:#ffffff;fill-rule:evenodd;stroke-width:0.264583"
         d="M 59.999954,19.999813 A 39.999999,39.999999 0 0 0 19.999813,59.999954 39.999999,39.999999 0 0 0 57.273507,99.897779 V 142.65486 H 153.96424 V 52.784375 H 99.343289 A 39.999999,39.999999 0 0 0 59.999954,19.999813 Z" />
      <path
         id="lpe_path-effect58"
         style="fill:#ffffff;fill-rule:evenodd;stroke-width:0.264583"
         class="powerclip"
         d="M -5,-5 H 125 V 125 H -5 Z M 59.999954,19.999813 A 39.999999,39.999999 0 0 0 19.999813,59.999954 39.999999,39.999999 0 0 0 57.273507,99.897779 V 142.65486 H 153.96424 V 52.784375 H 99.343289 A 39.999999,39.999999 0 0 0 59.999954,19.999813 Z" />
    </clipPath>
  </defs>
  <g
     id="layer1">
    <path
       id="path31"
       style="fill:#fffffa;fill-opacity:1;fill-rule:evenodd;stroke-width:0.264583"
       d="M 120,60 A 60,60 0 0 1 60,120 60,60 0 0 1 0,60 60,60 0 0 1 60,0 60,60 0 0 1 120,60 Z"
       clip-path="url(#clipPath54)"
       />
    <path
       id="path543"
       style="stroke-width:0.264583;fill:#fffffa;fill-opacity:1"
       d="m 68.09359,109.71313 a 10,10 0 0 1 -10,10 10,10 0 0 1 -10,-10 10,10 0 0 1 10,-10.000007 10,10 0 0 1 10,10.000007 z" />
    <path
       id="rect771"
       style="stroke-width:0.264583;fill:#fffffa;fill-opacity:1"
       d="M 102.39539,71.628794 82.940764,57.574701 C 78.449989,54.330548 77.44639,48.103511 80.690543,43.612735 83.934696,39.12196 90.161732,38.11836 94.652508,41.362513 l 19.454622,14.054092 c 4.49078,3.244154 5.49439,9.471192 2.25023,13.961968 -3.24415,4.490776 -9.47119,5.494374 -13.96197,2.250221 z" />
    <path
       id="rect771-3"
       style="stroke-width:0.264583;fill:#fffffa;fill-opacity:1"
       d="m 103.20261,57.201487 14.91447,-18.803158 c 3.44276,-4.340396 9.70861,-5.063044 14.04901,-1.620288 4.34039,3.442755 5.06305,9.708614 1.62029,14.04901 l -14.91446,18.803156 c -3.44277,4.340396 -9.70862,5.063045 -14.04902,1.620289 -4.34039,-3.442756 -5.063037,-9.708614 -1.62029,-14.049009 z" />
  </g>
</svg>
        
        
        <p class="reloadtext">Reload</p>
        
        </a>
      </div>

    </div>
  </body>
</html>                  """);
                                },

                                androidOnPermissionRequest: (controller, origin, resources) async {
                                  return PermissionRequestResponse(
                                      resources: resources,
                                      action: PermissionRequestResponseAction.GRANT);
                                },

                                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                                  setState(() {
                                    this.url = url.toString();
                                    urlController.text = this.url;
                                  });
                                },
                              ); }),
                              progress < 1.0
                                  ? LinearProgressIndicator(value: progress,
                                // colors for the load bar and the background
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xfffffffa)),
                                backgroundColor: const Color(0xfffb5137),
                              )
                                  : Container(),
                            ],
                          ),
                        ),
                    ]))),
          ));
  }
}
