#+private
//#+feature dynamic-literals
package winpdfgenerator

import "core:fmt"
import "core:strings"

Pdf_Function_Kind :: enum {
	Sampled     = 0,
	Exponential = 2,
	Stitching   = 3,
	PostScript  = 4,
}

// CORRECCIÓN: domain es [2]f32 para [xmin xmax] (§Table 38). Era [5]f32.
Pdf_Function_Type2 :: struct {
	domain: [2]f32,
	range:  []f32,
	c0:     []f32,
	c1:     []f32,
	n:      f32,
}

Pdf_Function_Type4 :: struct {
	domain: []f32,
	range:  []f32,
	code:   string,
}

function_type2_to_dict :: proc(f: Pdf_Function_Type2) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/FunctionType"] = i64(2)

	// CORRECCIÓN: acceso a índices 0 y 1 del [2]f32. Antes era f.domain[7].
	domain_arr := make([dynamic]Pdf_Object)
	append(&domain_arr, f.domain[0])
	append(&domain_arr, f.domain[1])
	d["/Domain"] = domain_arr

	if len(f.range) > 0 {
		range_arr := make([dynamic]Pdf_Object)
		for r in f.range { append(&range_arr, r) }
		d["/Range"] = range_arr
	}

	c0_arr := make([dynamic]Pdf_Object)
	for val in f.c0 { append(&c0_arr, val) }
	d["/C0"] = c0_arr

	c1_arr := make([dynamic]Pdf_Object)
	for val in f.c1 { append(&c1_arr, val) }
	d["/C1"] = c1_arr

	d["/N"] = f.n
	return d
}

function_type4_to_stream :: proc(f: Pdf_Function_Type4) -> Pdf_Stream {
	s: Pdf_Stream
	s.dict = make(Pdf_Dict)
	s.dict["/FunctionType"] = i64(4)

	domain_arr := make([dynamic]Pdf_Object)
	for val in f.domain { append(&domain_arr, val) }
	s.dict["/Domain"] = domain_arr

	range_arr := make([dynamic]Pdf_Object)
	for val in f.range { append(&range_arr, val) }
	s.dict["/Range"] = range_arr

	s.contents = transmute([]byte)f.code
	return s
}
