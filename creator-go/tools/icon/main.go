package main

import (
	"image"
	"image/color"
	"image/png"
	"os"
)

func main() {
	im := image.NewRGBA(image.Rect(0, 0, 512, 512))
	round := func(x, y, w, h, r int, c color.RGBA) {
		for py := y; py < y+h; py++ {
			for px := x; px < x+w; px++ {
				cx := px
				if cx < x+r {
					cx = x + r
				}
				if cx > x+w-r-1 {
					cx = x + w - r - 1
				}
				cy := py
				if cy < y+r {
					cy = y + r
				}
				if cy > y+h-r-1 {
					cy = y + h - r - 1
				}
				if (px-cx)*(px-cx)+(py-cy)*(py-cy) <= r*r {
					im.SetRGBA(px, py, c)
				}
			}
		}
	}
	round(0, 0, 512, 512, 110, color.RGBA{0, 125, 113, 255})
	round(86, 148, 236, 216, 52, color.RGBA{255, 255, 255, 255})
	for y := 168; y < 344; y++ {
		for x := 338; x < 426; x++ {
			half := 44 + (x-338)/2
			if y >= 256-half && y <= 256+half {
				im.SetRGBA(x, y, color.RGBA{255, 255, 255, 255})
			}
		}
	}
	for y := 198; y < 314; y++ {
		for x := 146; x < 262; x++ {
			if (x-204)*(x-204)+(y-256)*(y-256) < 58*58 {
				im.SetRGBA(x, y, color.RGBA{0, 125, 113, 255})
			}
		}
	}
	f, e := os.Create("build/appicon.png")
	if e != nil {
		panic(e)
	}
	defer f.Close()
	if e = png.Encode(f, im); e != nil {
		panic(e)
	}
}
