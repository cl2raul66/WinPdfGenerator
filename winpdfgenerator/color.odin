#+private
//#+feature dynamic-literals
package winpdfgenerator

import "core:fmt"
import "core:strings"

Color_Gray :: struct { g: f32 }
Color_RGB  :: struct { r, g, b: f32 }
Color_CMYK :: struct { c, m, y, k: f32 }

Rendering_Intent :: enum {
	AbsoluteColorimetric,
	RelativeColorimetric,
	Saturation,
	Perceptual,
}

rendering_intent_to_name :: proc(ri: Rendering_Intent) -> Pdf_Name {
	switch ri {
	case .AbsoluteColorimetric: return Pdf_Name("/AbsoluteColorimetric")
	case .RelativeColorimetric: return Pdf_Name("/RelativeColorimetric")
	case .Saturation:           return Pdf_Name("/Saturation")
	case .Perceptual:           return Pdf_Name("/Perceptual")
	}
	return Pdf_Name("/RelativeColorimetric")
}

Cie_White_Point :: distinct [3]f32
Cie_Black_Point :: distinct [3]f32

Cal_Gray_Params :: struct {
	white_point: Cie_White_Point,
	black_point: Cie_Black_Point,
	gamma:       f32,
}

Cal_RGB_Params :: struct {
	white_point:  Cie_White_Point,
	black_point:  Cie_Black_Point,
	gamma:        [3]f32,
	color_matrix: [9]f32,
}

Lab_Params :: struct {
	white_point: Cie_White_Point,
	black_point: Cie_Black_Point,
	range:       [4]f32,
}

ICC_Color_Space :: struct {
	n:   int,
	ref: Pdf_Ref,
}

Indexed_Color_Space :: struct {
	base:   Pdf_Object,
	hival:  int,
	lookup: []byte,
}

Separation_Params :: struct {
	name:            Pdf_Name,
	alternate_space: Pdf_Object,
	tint_transform:  Pdf_Ref,
}

DeviceN_Params :: struct {
	names:           []Pdf_Name,
	alternate_space: Pdf_Object,
	tint_transform:  Pdf_Ref,
	attributes:      Pdf_Dict,
}

Color_Space :: union {
	Cal_Gray_Params,
	Cal_RGB_Params,
	Lab_Params,
	ICC_Color_Space,
	Indexed_Color_Space,
	Separation_Params,
	DeviceN_Params,
}

// ── Operadores de Color (§8.6.8) ─────────────────────────────────────────────

write_fill_rgb :: proc(sb: ^strings.Builder, c: Color_RGB) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f rg\n", c.r, c.g, c.b)
}

write_fill_gray :: proc(sb: ^strings.Builder, c: Color_Gray) {
	fmt.sbprintf(sb, "%.4f g\n", c.g)
}

write_fill_cmyk :: proc(sb: ^strings.Builder, c: Color_CMYK) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f k\n", c.c, c.m, c.y, c.k)
}

write_stroke_rgb :: proc(sb: ^strings.Builder, c: Color_RGB) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f RG\n", c.r, c.g, c.b)
}

write_stroke_gray :: proc(sb: ^strings.Builder, c: Color_Gray) {
	fmt.sbprintf(sb, "%.4f G\n", c.g)
}

write_stroke_cmyk :: proc(sb: ^strings.Builder, c: Color_CMYK) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f K\n", c.c, c.m, c.y, c.k)
}

write_color_space_name :: proc(sb: ^strings.Builder, name: Pdf_Name, for_stroke: bool) {
	fmt.sbprintf(sb, "%s %s\n", name, for_stroke ? "CS" : "cs")
}

// Helper interno: construye un [dynamic]Pdf_Object desde valores f32
@(private)
pdf_f32_array :: proc(vals: ..f32) -> [dynamic]Pdf_Object {
	arr := make([dynamic]Pdf_Object)
	for v in vals { append(&arr, v) }
	return arr
}

color_space_to_pdf :: proc(cs: Color_Space) -> Pdf_Object {
	switch v in cs {
	case Cal_Gray_Params:
		d := make(Pdf_Dict)
		d["/WhitePoint"] = pdf_f32_array(v.white_point[0], v.white_point[1], v.white_point[2])
		d["/BlackPoint"] = pdf_f32_array(v.black_point[0], v.black_point[1], v.black_point[2])
		d["/Gamma"]      = v.gamma
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/CalGray"))
		append(&arr, d)
		return arr

	case Cal_RGB_Params:
		d := make(Pdf_Dict)
		d["/WhitePoint"] = pdf_f32_array(v.white_point[0], v.white_point[1], v.white_point[2])
		d["/BlackPoint"] = pdf_f32_array(v.black_point[0], v.black_point[1], v.black_point[2])
		d["/Gamma"]      = pdf_f32_array(v.gamma[0], v.gamma[1], v.gamma[2])
		matrix_arr := make([dynamic]Pdf_Object)
		for m in v.color_matrix { append(&matrix_arr, m) }
		d["/Matrix"] = matrix_arr
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/CalRGB"))
		append(&arr, d)
		return arr

	case Lab_Params:
		d := make(Pdf_Dict)
		d["/WhitePoint"] = pdf_f32_array(v.white_point[0], v.white_point[1], v.white_point[2])
		d["/BlackPoint"] = pdf_f32_array(v.black_point[0], v.black_point[1], v.black_point[2])
		d["/Range"]      = pdf_f32_array(v.range[0], v.range[1], v.range[2], v.range[3])
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/Lab"))
		append(&arr, d)
		return arr

	case ICC_Color_Space:
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/ICCBased"))
		append(&arr, v.ref)
		return arr

	case Indexed_Color_Space:
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/Indexed"))
		append(&arr, v.base)
		append(&arr, i64(v.hival))
		append(&arr, transmute(string)v.lookup)
		return arr

	case Separation_Params:
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/Separation"))
		append(&arr, v.name)
		append(&arr, v.alternate_space)
		append(&arr, v.tint_transform)
		return arr

	case DeviceN_Params:
		arr := make([dynamic]Pdf_Object)
		append(&arr, Pdf_Name("/DeviceN"))
		names_arr := make([dynamic]Pdf_Object)
		for n in v.names { append(&names_arr, n) }
		append(&arr, names_arr)
		append(&arr, v.alternate_space)
		append(&arr, v.tint_transform)
		if len(v.attributes) > 0 { append(&arr, v.attributes) }
		return arr
	}
	return nil
}
