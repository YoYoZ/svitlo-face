import Toybox.Graphics;
import Toybox.Lang;

// MIP watches: draw straight to the screen, black and white.
module Screen {
    const COLOR = false;
    function size(dc as Dc) as Number { return dc.getWidth(); }
    function begin(dc as Dc) as Dc { return dc; }
    function finish(dc as Dc) as Void { }
}
