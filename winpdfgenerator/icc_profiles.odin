#+private
package winpdfgenerator

// Flujo de Perfil ICC (ISO 32000-2 §8.6.5.5, §Table 65)
Icc_Profile_Stream :: struct {
	num_components: int,     // N: 1, 3 o 4 (§Table 65)
	alternate:      Pdf_Name, // Espacio alternativo (ej: /DeviceRGB, /DeviceCMYK)
	data:           []byte,  // Datos binarios crudos del archivo .icc
}

icc_profile_to_stream :: proc(icc: Icc_Profile_Stream) -> Pdf_Stream {
	s: Pdf_Stream
	s.dict = make(Pdf_Dict)
	s.dict["/N"] = i64(icc.num_components)

	if len(icc.alternate) > 0 {
		s.dict["/Alternate"] = icc.alternate
	}

	// CORRECCIÓN: Antes se declaraba /Filter /FlateDecode pero los datos se
	// almacenaban sin comprimir (s.contents = icc.data directamente), lo que
	// produciría un PDF corrupto porque el visor intentaría descomprimir datos
	// que no están comprimidos.
	// Ahora se aplica la compresión real. Si falla, se almacenan sin filtro.
	compressed, ok := filter_apply_flate(icc.data)
	if ok && len(compressed) < len(icc.data) {
		s.dict["/Filter"] = Pdf_Name("/FlateDecode")
		s.contents = compressed
	} else {
		// Sin filtro si la compresión no reduce el tamaño (posible con datos
		// ya comprimidos, como perfiles ICC modernos).
		s.contents = icc.data
	}

	return s
}
