Prolific P Finder
=================

This code is forked from Carl Brown's original for his ["Apps That Can See" talk at 360iDev 2013](http://www.slideshare.net/carlbrown/writing-apps-that-can-see). It makes great use of [OpenCV](http://opencv.org/), an open source computer vision library.

Running the "ProlificPFinder" project will launch an app that will detect a [Prolific P logo](http://prolificinteractive.com/wp-content/themes/prolific/images/home/logo.png) if it is somewhere on the screen. Currently there is just the basic test of the logo itself, then a negative case with a "fake" logo, then a positive case with the logo and a bunch of other shapes thrown in to try and confuse the computer.

The original demo from Carl used `HoughLinesP` to decode a Rubik's cube, but I used `HoughCircles` to detect the big circle and the little circle in the P logo. Then I used a series of tests to match the image:

* Did `HoughCircles` find at least two circles?
* Is the ratio between the large radius and the small radius within an acceptable range?
* Is the distance between the two circles' centers in an acceptable range (after scaling by the large circle's radius)?

If the output from `HoughCircles` passes all three tests, I call it a match. This is by no means 100% fool-proof, but it at least is able to handle the 3 demo test cases I put together here.

[I wrote a blog post explaining the thought process behind the project thus far.](http://www.mattluedke.com/my-first-tomhackery-with-computer-vision/)