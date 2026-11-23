import Toybox.Graphics;
import Toybox.Lang;

// AMOLED (390x390): the face is drawn at 195x195 into an off-screen bitmap, then shown
// scaled 2x with point filtering. Every face pixel becomes a crisp 2x2 block: the same
// retro LCD look and the same layout code as the 176 px Instinct screens.
module Screen {
    const COLOR = true;
    const S = 195;
    var buf = null;
    var xf = null;

    function size(dc as Dc) as Number { return S; }

    function begin(dc as Dc) as Dc {
        if (buf == null) {
            buf = Graphics.createBufferedBitmap({:width => S, :height => S}).get();
            xf = new Graphics.AffineTransform();
            xf.scale(dc.getWidth().toFloat() / S, dc.getHeight().toFloat() / S);
        }
        return (buf as BufferedBitmap).getDc();
    }

    function finish(dc as Dc) as Void {
        dc.drawBitmap2(0, 0, buf as BufferedBitmap, {:transform => xf, :filterMode => Graphics.FILTER_MODE_POINT});
    }
}
