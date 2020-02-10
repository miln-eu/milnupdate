# Publishing a Miln Update Release

This document describes how to prepare and publish a release of Miln Update. This document does not cover updates for applications that use the Miln Update frameworks; for that, see the project's primary read me file.

## Creating a Release

1. Update the `frameworks/version.xcconfig` version number.
2. Check in outstanding changes into version control; tag the revision.
3. Call the distribution makefile:
    
    ``` sh
    cd distribution && makefile release
    ```

4. Manually verify the new archive in `/distribution`
5. Copy the archive to the web site.
6. Update the web site's generic filename redirection to the new archive.
