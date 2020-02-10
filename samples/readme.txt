## Samples

These sample projects require setting up UpdateCore's code signing:

1. In the parent directory containing the `milnupdate` directory, create a file called `milnupdate.xcconfig`:
  
   - MyProject/
	 - milnupdate.xcconfig
	 - milnupdate/

2. Within `milnupdate.xcconfig` override the essential settings:
    
    ```
    MILNUPDATE_APP_NAME = Your Application Name
    MILNUPDATE_APP_BUNDLE = com.example.application
    MILNUPDATE_APP_CERTIFICATE[sdk=*][arch=*] = Developer ID Application: Your Company Name (ABC123XY)
    DEVELOPMENT_TEAM = ABC123XY
    CODE_SIGN_IDENTITY[sdk=*][arch=*] = Developer ID Application
    ```

These settings are documented in `milnupdate/frameworks/updatecore/updatecore.xcconfig`.