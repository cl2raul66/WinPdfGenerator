#+private
package winpdfgenerator

import "core:strings"

// write_header emite la cabecera PDF 2.0 con el comentario binario obligatorio
// (bytes > 127) para que las herramientas de transferencia traten el archivo
// como binario (ISO 32000-2 §7.5.2).
write_header :: proc(sb: ^strings.Builder) {
    strings.write_string(sb, "%PDF-2.0\n")
    strings.write_string(sb, "%%\u00E2\u00E3\u00CF\u00D3\n")
}
