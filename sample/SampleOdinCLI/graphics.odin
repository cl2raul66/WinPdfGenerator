package winpdfgenerator

import "core:fmt"
import "core:strings"

write_path_ops :: proc(sb: ^strings.Builder, obj: ^Pdf_Page_Path_Object) {
    fmt.sbprintf(sb, "q\n%.4f w\n", obj.line_width)
    if obj.stroked {
        c := obj.stroke_color
        fmt.sbprintf(sb, "%.4f %.4f %.4f RG\n", c.r, c.g, c.b)
    }
    if obj.filled {
        c := obj.fill_color
        fmt.sbprintf(sb, "%.4f %.4f %.4f rg\n", c.r, c.g, c.b)
    }
    for cmd in obj.commands {
        switch cmd.kind {
        case .Move_To:
            fmt.sbprintf(sb, "%.4f %.4f m\n", cmd.pts[0][0], cmd.pts[0][1])
        case .Line_To:
            fmt.sbprintf(sb, "%.4f %.4f l\n", cmd.pts[0][0], cmd.pts[0][1])
        case .Curve_To:
            fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f %.4f %.4f c\n",
                cmd.pts[0][0], cmd.pts[0][1],
                cmd.pts[1][0], cmd.pts[1][1],
                cmd.pts[2][0], cmd.pts[2][1])
        case .Close:
            strings.write_string(sb, "h\n")
        }
    }
    switch {
    case obj.filled && obj.stroked: strings.write_string(sb, "B\n")
    case obj.filled:                strings.write_string(sb, "f\n")
    case obj.stroked:               strings.write_string(sb, "S\n")
    }
    strings.write_string(sb, "Q\n")
}
