# DejaTextView

DejaTextView is a UITextView subclass with improved text selection and cursor movement tools. Written in Swift.

![DejaTextView demo loop](http://markusschlegel.github.io/DejaTextView.gif)

## Insallation

Add the following line to your `Podfile`:

```ruby
pod 'DejaTextView', :git => 'https://github.com/markusschlegel/DejaTextView.git'
```

You might also just fish out the source file at `Pod/Classes/DejaTextView.swift`.

## Usage

DejaTextView is mostly a drop-in replacement for UITextView, so just use it everywhere you like as if it was a standard UITextView. There’s one exception though. If you want to add your own gesture recognizers, you have to use the method addGestureRecognizerForReal(gestureRecognizer: UIGestureRecognizer). This is unfortunate, but maybe I find a way to handle this better in the future.

## Known issues

* On the iPad, the copy/paste menu will not appear if the keyboard is undocked and or split.
* The black grabbers may move beyond the bounds of the text view in vertical direction. Make sure there is enough space above and below the text view where the grabbers can move.

## Author

Markus Schlegel, mail@markus-schlegel.com

## License

DejaTextView is available under the MIT license. See the LICENSE file for more info.
