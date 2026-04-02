#+private
//#+feature dynamic-literals
package winpdfgenerator

import "core:fmt"
import "core:strings"

Shading_Pattern :: struct {
	shading_type: int,
	color_space:  Pdf_Object,
	coords:       []f32,
	function:     Pdf_Ref,
	// CORRECCIÓN: Era [3]bool. §Table 78 especifica exactamente 2 booleanos [start end].
	extend:       [2]bool,
}

write_shading_fill :: proc(sb: ^strings.Builder, name: Pdf_Name) {
	fmt.sbprintf(sb, "%s sh\n", name)
}

shading_to_pdf :: proc(sh: Shading_Pattern) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/ShadingType"] = i64(sh.shading_type)
	d["/ColorSpace"]  = sh.color_space
	d["/Function"]    = sh.function

	// CORRECCIÓN: []f32 no es Pdf_Object, debe convertirse.
	coords_arr := make([dynamic]Pdf_Object)
	for c in sh.coords { append(&coords_arr, c) }
	d["/Coords"] = coords_arr

	// CORRECCIÓN: Era sh.extend[4] (fuera de límites). /Extend tiene 2 elementos.
	extend_arr := make([dynamic]Pdf_Object)
	append(&extend_arr, sh.extend[0])
	append(&extend_arr, sh.extend[1])
	d["/Extend"] = extend_arr

	return d
}
