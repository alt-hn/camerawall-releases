// Render the app's vector geometry with supersampling for macOS/Windows icons.
package main

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os"
)

func main() {
	const scale = 4
	im := image.NewRGBA(image.Rect(0, 0, 512*scale, 512*scale))
	paint := func(x, y, w, h, r int, c color.RGBA) {
		x *= scale
		y *= scale
		w *= scale
		h *= scale
		r *= scale
		for py := y; py < y+h; py++ {
			for px := x; px < x+w; px++ {
				cx := max(x+r, min(px, x+w-r-1))
				cy := max(y+r, min(py, y+h-r-1))
				if (px-cx)*(px-cx)+(py-cy)*(py-cy) <= r*r {
					im.SetRGBA(px, py, c)
				}
			}
		}
	}
	circle := func(cx, cy, r int, c color.RGBA) {
		cx *= scale
		cy *= scale
		r *= scale
		for y := cy - r; y < cy+r; y++ {
			for x := cx - r; x < cx+r; x++ {
				if (x-cx)*(x-cx)+(y-cy)*(y-cy) <= r*r {
					im.SetRGBA(x, y, c)
				}
			}
		}
	}
	navy := color.RGBA{19, 46, 57, 255}
	teal := color.RGBA{32, 190, 167, 255}
	white := color.RGBA{245, 252, 251, 255}
	paint(20, 20, 472, 472, 106, navy)
	paint(198, 76, 116, 100, 19, color.RGBA{155, 184, 186, 255})
	paint(219, 96, 22, 34, 5, navy)
	paint(271, 96, 22, 34, 5, navy)
	paint(150, 151, 212, 278, 52, white)
	circle(256, 270, 69, navy)
	circle(256, 270, 54, teal)
	circle(256, 270, 37, navy)
	circle(240, 253, 10, white)
	paint(225, 372, 62, 9, 4, teal)
	out := image.NewRGBA(image.Rect(0, 0, 1024, 1024))
	for y := 0; y < 1024; y++ {
		for x := 0; x < 1024; x++ {
			var r, g, b, a uint32
			for dy := 0; dy < 2; dy++ {
				for dx := 0; dx < 2; dx++ {
					c := im.RGBAAt(x*2+dx, y*2+dy)
					r += uint32(c.R)
					g += uint32(c.G)
					b += uint32(c.B)
					a += uint32(c.A)
				}
			}
			out.SetRGBA(x, y, color.RGBA{uint8(r / 4), uint8(g / 4), uint8(b / 4), uint8(a / 4)})
		}
	}
	var encoded bytes.Buffer
	if e := png.Encode(&encoded, out); e != nil {
		panic(e)
	}
	for _, path := range []string{"build/appicon.png", "frontend/appicon.png"} {
		if e := os.WriteFile(path, encoded.Bytes(), 0644); e != nil {
			panic(e)
		}
	}
}
