#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

write_header :: proc(sb: ^strings.Builder) {
    strings.write_string(sb, "%%PDF-2.0\n")
    strings.write_string(sb, "%%\u00E2\u00E3\u00CF\u00D3\n")
}

write_xref :: proc(sb: ^strings.Builder, entries: []XRef_Entry) {
    fmt.sbprintf(sb, "xref\n0 %d\n", len(entries) + 1)
    strings.write_string(sb, "0000000000 65535 f \r\n")
    for entry in entries {
        flag := entry.in_use ? 'n' : 'f'
        fmt.sbprintf(sb, "%010d %05d %c \r\n", entry.offset, entry.gen, flag)
    }
}

write_trailer :: proc(sb: ^strings.Builder, size: int, root_id: int, xref_offset: i64, id0, id1: []byte) {
    fmt.sbprintf(sb, "trailer\n<<\n  /Size %d\n  /Root %d 0 R\n  /ID [<", size + 1, root_id)
    for b in id0 do fmt.sbprintf(sb, "%02x", b)
    strings.write_string(sb, "> <")
    for b in id1 do fmt.sbprintf(sb, "%02x", b)
    strings.write_string(sb, ">]\n>>\n")
    fmt.sbprintf(sb, "startxref\n%d\n", xref_offset)
    strings.write_string(sb, "%%EOF")
}
