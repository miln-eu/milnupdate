software-update.pdf created with Entypo font (CC BY-SA 3.0).

# PNG to ICNS

``` shell
mkdir software-update.iconset
sips ../software-update.png -Z 16 --out icon_16x16.png
sips ../software-update.png -Z 32 --out icon_16x16@2x.png
sips ../software-update.png -Z 32 --out icon_32x32.png
sips ../software-update.png -Z 64 --out icon_32x32@2x.png
sips ../software-update.png -Z 128 --out icon_128x128.png
sips ../software-update.png -Z 256 --out icon_128x128@2x.png
sips ../software-update.png -Z 256 --out icon_256x256.png
sips ../software-update.png -Z 512 --out icon_256x256@2x.png
sips ../software-update.png -Z 512 --out icon_512x512.png
sips ../software-update.png -Z 1024 --out icon_512x512@2x.png
cd ..
iconutil -c icns software-update.iconset
```