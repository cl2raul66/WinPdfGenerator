#+private
package winpdfgenerator

import "core:strings"
import zlib "vendor:zlib"

Filter_Kind :: enum {
	Flate_Decode,
	ASCII_Hex_Decode,
	ASCII_85_Decode,
	LZW_Decode,
	Run_Length_Decode,
	DCT_Decode,
	JPX_Decode,
	Crypt,
}

Predictor_Kind :: enum {
	None        = 1,
	TIFF_2      = 2,
	PNG_None    = 10,
	PNG_Sub     = 11,
	PNG_Up      = 12,
	PNG_Average = 13,
	PNG_Paeth   = 14,
	PNG_Optimum = 15,
}

Flate_Params :: struct {
	predictor:          Predictor_Kind,
	colors:             int,
	bits_per_component: int,
	columns:            int,
}

Filter_Config :: struct {
	kind:  Filter_Kind,
	flate: Maybe(Flate_Params),
}

filter_apply_flate :: proc(data: []byte) -> (result: []byte, ok: bool) {
	if len(data) == 0 { return nil, true }

	bound := zlib.compressBound(zlib.uLong(len(data)))
	result  = make([]byte, bound)

	dest_len := bound
	status := zlib.compress2(
		raw_data(result),
		&dest_len,
		raw_data(data),
		zlib.uLong(len(data)),
		zlib.BEST_COMPRESSION,
	)

	if status != 0 {
		delete(result)
		return nil, false
	}

	return result[:dest_len], true
}

filter_apply_ascii85 :: proc(src: []byte) -> []byte {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	i := 0
	for i < len(src) {
		remaining := len(src) - i
		chunk_len := min(remaining, 4)

		val: u32 = 0
		for j in 0..<4 {
			val <<= 8
			if j < chunk_len { val |= u32(src[i + j]) }
		}

		if val == 0 && chunk_len == 4 {
			strings.write_byte(&sb, 'z')
		} else {
			out: [5]byte
			v := val
			for j := 4; j >= 0; j -= 1 {
				out[j] = byte((v % 85) + 33)
				v /= 85
			}
			strings.write_bytes(&sb, out[:chunk_len + 1])
		}
		i += chunk_len
	}

	strings.write_string(&sb, "~>")

	s := strings.to_string(sb)
	result := make([]byte, len(s))
	copy(result, transmute([]byte)s)
	return result
}

@(private)
flate_params_to_pdf :: proc(p: Flate_Params) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Predictor"] = i64(p.predictor)
	if p.colors             > 0 { d["/Colors"]           = i64(p.colors) }
	if p.bits_per_component > 0 { d["/BitsPerComponent"] = i64(p.bits_per_component) }
	if p.columns            > 0 { d["/Columns"]          = i64(p.columns) }
	return d
}

apply_filters_to_stream :: proc(s: ^Pdf_Stream, configs: []Filter_Config) {
	if len(configs) == 0 { return }

	if len(configs) == 1 {
		c := configs[0]
		s.dict["/Filter"] = filter_kind_to_name(c.kind)
		if p, ok := c.flate.?; ok {
			s.dict["/DecodeParms"] = flate_params_to_pdf(p)
		}
	} else {
		filters := make([dynamic]Pdf_Object)
		parms   := make([dynamic]Pdf_Object)
		for c in configs {
			append(&filters, filter_kind_to_name(c.kind))
			if p, ok := c.flate.?; ok {
				append(&parms, flate_params_to_pdf(p))
			} else {
				append(&parms, Pdf_Null{})
			}
		}
		s.dict["/Filter"]      = filters
		s.dict["/DecodeParms"] = parms
	}
}

@(private)
filter_kind_to_name :: proc(k: Filter_Kind) -> Pdf_Name {
	switch k {
	case .Flate_Decode:      return Pdf_Name("/FlateDecode")
	case .ASCII_Hex_Decode:  return Pdf_Name("/ASCIIHexDecode")
	case .ASCII_85_Decode:   return Pdf_Name("/ASCII85Decode")
	case .LZW_Decode:        return Pdf_Name("/LZWDecode")
	case .Run_Length_Decode: return Pdf_Name("/RunLengthDecode")
	case .DCT_Decode:        return Pdf_Name("/DCTDecode")
	case .JPX_Decode:        return Pdf_Name("/JPXDecode")
	case .Crypt:             return Pdf_Name("/Crypt")
	}
	return Pdf_Name("/FlateDecode")
}
