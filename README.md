# ImgurUploader

Uploads images "anonymously" (i.e. unassociated with an account) using version 3 of the Imgur API.

This project is focused on taking an image in an iOS app and uploading it to Imgur. It has no interest in providing a full-featured Imgur API client or in working effectively on other platforms. Because the scope is so narrow, we can make the functionality we do offer as comfortable as possible:

* We accept the image types you're probably already using.
* We make it easy to upload images directly from an image picker.
* We cheerfully resize that gigantic image until it ducks below the Imgur file size limit.
* We resize that gigantic image without getting you terminated for eating all the device's memory.

## Getting started

You need to register your application with Imgur and otherwise comply with their terms. [Please read the Introduction section of the Imgur API documentation.](https://apidocs.imgur.com) At the time of writing, the Imgur API can be used for free for *non-commercial usage*. This project does not support commercial usage (though pull requests are welcome!). Once you've registered your application, record the Client ID that Imgur gives you. You'll need it to use this library!

Next step is to get a copy of this library. We support Carthage, CocoaPods, and Swift Package Manager, as well as just plopping a copy directly into your project.

## Development

Open the Xcode project and dig in!
