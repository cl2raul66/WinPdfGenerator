#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Image XObject (ISO 32000-2 §8.9.5) ────────────────────────

Image_XObject :: struct {
	width:              int,
	height:             int,
	color_space:        Pdf_Object, // Nombre (ej: /DeviceRGB) o array
	bits_per_component: int,        // 1, 2, 4, 8 o 16 (§Table 86)
	data:               []byte,     // Datos de imagen (crudos o ya filtrados)
	filters:            []Filter_Config,
	mask:               Maybe(Pdf_Ref), // Máscara explícita o Stencil Mask (§8.9.6)
	smask:              Maybe(Pdf_Ref), // Soft Mask para transparencia (§11.6.5)
	intent:             Maybe(Rendering_Intent), // Intento de renderizado (§8.6.5.8)
	interpolate:        bool, // Suavizado en reescalado (§8.9.5.3)
}

// Genera el Pdf_Stream del Image XObject.
image_xobject_to_stream :: proc(img: Image_XObject) -> Pdf_Stream {
	s: Pdf_Stream
	s.dict = make(Pdf_Dict)

	s.dict["/Type"]             = Pdf_Name("/XObject")
	s.dict["/Subtype"]          = Pdf_Name("/Image")
	s.dict["/Width"]            = i64(img.width)
	s.dict["/Height"]           = i64(img.height)
	s.dict["/ColorSpace"]       = img.color_space
	s.dict["/BitsPerComponent"] = i64(img.bits_per_component)

	if img.interpolate {
		s.dict["/Interpolate"] = true
	}
	if ri, ok := img.intent.?; ok {
		s.dict["/Intent"] = rendering_intent_to_name(ri)
	}
	if mask_ref, ok := img.mask.?; ok {
		s.dict["/Mask"] = mask_ref
	}
	if smask_ref, ok := img.smask.?; ok {
		s.dict["/SMask"] = smask_ref
	}

	apply_filters_to_stream(&s, img.filters)
	s.contents = img.data
	return s
}

// Escribe los operadores q/cm/Do/Q en el content stream de la página.
// 'alias' es el nombre del recurso en /XObject del diccionario de la página (ej: /Im1).
write_image_do :: proc(sb: ^strings.Builder, alias: Pdf_Name, x, y, width, height: f32) {
	// En el sistema de coordenadas PDF, el origen es la esquina inferior izquierda.
	// La matriz [width 0 0 height x y] escala la imagen de 1×1 a width×height
	// y la traslada al punto (x, y) (§8.3.4).
	fmt.sbprintf(sb, "q\n")
	fmt.sbprintf(sb, "%.4f 0 0 %.4f %.4f %.4f cm\n", width, height, x, y)
	fmt.sbprintf(sb, "%s Do\n", alias)
	fmt.sbprintf(sb, "Q\n")
}

// Stencil Masking (ISO 32000-2 §8.9.6.2):
// imagen de 1 bit pintada con el color de relleno actual.
write_stencil_mask :: proc(
	sb: ^strings.Builder,
	alias: Pdf_Name,
	x, y, width, height: f32,
	color: Color_RGB,
) {
	// Establece color de relleno (write_fill_rgb definido en color.odin)
	write_fill_rgb(sb, color)
	write_image_do(sb, alias, x, y, width, height)
}
