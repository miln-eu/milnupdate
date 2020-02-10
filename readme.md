# Miln Update

Miln Update adds a secure update mechanism to sandboxed and notarised macOS applications.

Miln Update includes UpdateCore and UpdateKit. UpdateCore provides the core functionality of discovering and applying updates. UpdateKit provides a ready-to-use user interface.

To learn more about Miln Update visit [https://indie.miln.eu](https://indie.miln.eu)

Miln Update is published under the Artistic License 2.0 by Graham Miln.

## Getting Started with UpdateKit

Let's create a macOS application in Xcode, add the update frameworks, and configure the essential settings:

### Create a New Application

1. Launch **Xcode.app**
2. Select the menu item: File (menu) > New > **Project…**
3. Choose the project template: macOS > **App**
4. Choose the options for your new project:
    1. Product Name: **MyExampleApp**
    2. Team: *Your Team Name*
  
   You can choose Objective-C or Swift. Miln Update works with both development languages.
   
### Add the Frameworks
   
1. Download [milnupdate.tbz](https://indie.miln.eu/tool/update/milnupdate.tbz) and expand the downloaded archive
2. Within the Finder, place the expanded `milnupdate` folder into the project's `MyExampleApp` folder:
  
   ```
   MyExampleApp/
   MyExampleApp/milnupdate/
   MyExampleApp/MyExampleApp/
   MyExampleApp/MyExampleApp.xcodeproj
   …
   ```
3. Within Xcode, add the framework projects **updatecore** and **updatekit** to your application project. Use the menu item: File (menu) > **Add Files to "MyExampleApp"…**
   and select the Xcode project files:   
   - MyExampleApp/milnupdate/frameworks/updatecore/updatecore.xcodeproj
   - MyExampleApp/milnupdate/frameworks/updatekit/updatekit.xcodeproj

4. Within Xcode's **Project Navigator**, select the top item, **MyExampleApp**
5. Within **Targets** select **MyExampleApp**
6. With the **MyExampleApp** target, select **Build Phases**
7. Expand the **Dependencies** build phase and use the **+** button to add two frameworks as dependencies:
    - UpdateCore
    - UpdateKit

8. Select the menu item: Editor > Add Build Phase > **Add Copy Files Build Phase**
9. Expand the new **Copy Files** build phase and change **Destination** to **Frameworks**
10. With the **Copy Files** build phase, use the **+** button to copy the two frameworks into the application: 
    - UpdateCore.framework
    - UpdateKit.framework

### Configure Code Signing

1. Select the menu item: File (menu) > New > **File…**
2. Choose the file template: macOS > **Configuration Settings File**
3. Save the file as **milnupdate.xcconfig** in the folder containing the `milnupdate` folder:

    ```
    MyExampleApp/
    MyExampleApp/milnupdate/
    MyExampleApp/milnupdate.xcconfig
    MyExampleApp/MyExampleApp/
    MyExampleApp/MyExampleApp.xcodeproj
    …
    ```
    
4. Within **milnupdate.xcconfig** copy, paste, and modify the settings below:

    ```
    MILNUPDATE_APP_NAME = MyExampleApp
    MILNUPDATE_APP_BUNDLE = com.example.myexampleapp
    MILNUPDATE_APP_CERTIFICATE[sdk=*][arch=*] = Developer ID Application: Your Company Name (ABC123XY)
    DEVELOPMENT_TEAM = ABC123XY
    CODE_SIGN_IDENTITY[sdk=*][arch=*] = Developer ID Application
    ```
    
    The critical settings to modify are the **MILNUPDATE_APP_CERTIFICATE** and **DEVELOPMENT_TEAM** values. These are unique to your Apple Developer certificate. These settings are overriding defaults in `MyExampleApp/milnupdate/frameworks/updatecore/updatecore.xcconfig`.

### Calling UpdateKit

Depending on the development language used, the syntax for initialising UpdateKit differs slightly.

UpdateKit needs to know where to find updates. Updates are discovered using a text based Really Simple Syndication (RSS) file. The URL used to check for updates is called the Discovery URL.

#### Calling UpdateKit with Swift

Within your project's application delegate, **AppDelegate.swift**, make these changes:

1. Import the UpdateKit framework:
    
    ```
    import UpdateKit
    ```

2. Add and initialise a class property:

    ```
    var updater: UKSoftwareUpdater! = UKSoftwareUpdater.init(discoveryURL: URL.init(string: "https://www.example.com/myexampleapp.xml")!)
    ```

#### Calling UpdateKit with Objective-C

Within your project's application delegate, **AppDelegate.m**, make these changes:

1. Import the UpdateKit framework:
    
    ```
    @import UpdateKit;
    ```

2. Add a class property:

    ```
    @property (strong) UKSoftwareUpdater* updater;
    ```

3. Within the `applicationDidFinishLaunching` method, create the updater:

    ```
    - (void)applicationDidFinishLaunching:(NSNotification*) aNotification {
        self.updater = [[UKSoftwareUpdater alloc] initWithDiscoveryURL:[NSURL URLWithString:@"https://www.example.com/myexampleapp.xml"]];
        …
    ```

### Build and Run

Your project is now ready to build and run.

You may encounter errors where Xcode can not initially find your `milnupdate.xcconfig` file. To fix this, **quit and relaunch Xcode**, then select the menu item: Product > **Clean Build Folder**.

#### Building with `xcodebuild`

When building with `xcodebuild`, provide an absolute path for `SYMROOT`. This will fix problems with missing modules:

    /usr/bin/xcrun xcodebuild SYMROOT=[/an/absolute/path]

### Publishing an Update

An update requires two parts: an RSS feed to discover updates and a package to download. These two files are distributed using a web server.

#### Create a Discovery RSS Feed

1. Copy and modify the XML file `milnupdate/samples/minimal.xml`. The essential values to change are the `enclosure` attributes for `version` and `url`.

The `version` attribute is compared to the application's Info.plist `CFBundleVersion`  value.

The `url` attribute must link to an Installer package containing the update to install.

#### Create a Package for Distribution

Updates are distributed as flat file macOS Installer packages (`.pkg` files). Miln Update includes a tool to create these packages from an application.

1. Use the `pkg-app.sh` tool to create a package containing your application:

    ```
    milnupdate/tools/pkg-app.sh --app [path/to/application]
    ```

2. Digitally sign the package using a **Developer ID Installer Certificate** from Apple:

    ```
    /usr/bin/productsign --sign <identity> myexampleapp-1.0.pkg myexampleapp-1.0-signed.pkg
    ```

3. Ask Apple to notarise the signed package:

    ```
    xcrun altool --notarize-app --file myexampleapp-1.0-signed.pkg
    ```

The signed package is now ready for distribution.

#### Upload the Files

Upload the signed package and discovery file to a web server. The web server must serve the discovery file for requests made to the URL provided to `UKSoftwareUpdater` in your application's code.

### Ready to Test

The final step is to test your new application and update.

The application will automatically check for updates once a week. When a new update is discovered the application will prompt the user to install.

## Getting Help and Support

Support contracts are available for help with integrating and customising Miln Update and for preparing update packages.