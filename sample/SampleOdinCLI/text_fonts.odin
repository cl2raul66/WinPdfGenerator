package winpdfgenerator

import "core:fmt"
import "core:strings"

write_text_ops :: proc(sb: ^strings.Builder, obj: ^Pdf_Page_Text_Object, font_alias: string) {
    fmt.sbprintf(sb, "BT\n")
    fmt.sbprintf(sb, "/%s %.4f Tf\n", font_alias, obj.font_size)
    fmt.sbprintf(sb, "%.4f %.4f %.4f rg\n", obj.color.r, obj.color.g, obj.color.b)
    fmt.sbprintf(sb, "%.4f %.4f Td\n", obj.x, obj.y)
    strings.write_string(sb, "(")
    pdf_escape_string(sb, obj.text)
    strings.write_string(sb, ") Tj\nET\n")
}

@(private)
pdf_escape_string :: proc(sb: ^strings.Builder, s: string) {
    for ch in s {
        switch ch {
        case '(':  strings.write_string(sb, "\\(")
        case ')':  strings.write_string(sb, "\\)")
        case '\\': strings.write_string(sb, "\\\\")
        case '\r': strings.write_string(sb, "\\r")
        case '\n': strings.write_string(sb, "\\n")
        case:      strings.write_rune(sb, ch)
        }
    }
}
