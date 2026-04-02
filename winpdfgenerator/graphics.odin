#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Estado Gráfico (ISO 32000-2 §8.4) ─────────────────────────

Line_Cap :: enum i64 {
	Butt   = 0,
	Round  = 1,
	Square = 2,
}

Line_Join :: enum i64 {
	Miter = 0,
	Round = 1,
	Bevel = 2,
}

Dash_Pattern :: struct {
	array: []f32,
	phase: f32,
}

// ── Operadores de Transformación y Estado (§8.4.4) ─────────────

// Modifica la CTM (Current Transformation Matrix)
write_concat_matrix :: proc(sb: ^strings.Builder, a, b, c, d, e, f: f32) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f %.4f %.4f cm\n", a, b, c, d, e, f)
}

write_line_width :: proc(sb: ^strings.Builder, width: f32) {
	fmt.sbprintf(sb, "%.4f w\n", width)
}

write_line_cap :: proc(sb: ^strings.Builder, cap: Line_Cap) {
	fmt.sbprintf(sb, "%d J\n", i64(cap))
}

write_line_join :: proc(sb: ^strings.Builder, join: Line_Join) {
	fmt.sbprintf(sb, "%d j\n", i64(join))
}

write_miter_limit :: proc(sb: ^strings.Builder, limit: f32) {
	fmt.sbprintf(sb, "%.4f M\n", limit)
}

write_dash :: proc(sb: ^strings.Builder, dash: Dash_Pattern) {
	strings.write_string(sb, "[")
	for val in dash.array { fmt.sbprintf(sb, "%.4f ", val) }
	fmt.sbprintf(sb, "] %.4f d\n", dash.phase)
}

// ── Construcción de Caminos (§8.5.2) ───────────────────────────

write_move_to :: proc(sb: ^strings.Builder, x, y: f32) {
	fmt.sbprintf(sb, "%.4f %.4f m\n", x, y)
}

write_line_to :: proc(sb: ^strings.Builder, x, y: f32) {
	fmt.sbprintf(sb, "%.4f %.4f l\n", x, y)
}

// Curva de Bézier cúbica (§8.5.2.1) — 3 puntos de control
write_curve_to :: proc(sb: ^strings.Builder, x1, y1, x2, y2, x3, y3: f32) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f %.4f %.4f c\n", x1, y1, x2, y2, x3, y3)
}

// Operador 'v': primer punto de control == punto actual (§8.5.2.1)
write_curve_to_v :: proc(sb: ^strings.Builder, x2, y2, x3, y3: f32) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f v\n", x2, y2, x3, y3)
}

write_close_path :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "h\n")
}

write_rectangle :: proc(sb: ^strings.Builder, x, y, w, h: f32) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f re\n", x, y, w, h)
}

// ── Pintado y Recorte (§8.5.3, §8.5.4) ─────────────────────────

write_stroke :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "S\n")
}

// f = Non-zero winding rule, f* = Even-odd rule (§8.5.3.3)
write_fill :: proc(sb: ^strings.Builder, even_odd := false) {
	strings.write_string(sb, even_odd ? "f*\n" : "f\n")
}

// B = Rellenar y trazar (§8.5.3)
write_fill_stroke :: proc(sb: ^strings.Builder, even_odd := false) {
	strings.write_string(sb, even_odd ? "B*\n" : "B\n")
}

// W = Establece camino de recorte seguido de 'n' (sin pintar, §8.5.4)
write_clip :: proc(sb: ^strings.Builder, even_odd := false) {
	strings.write_string(sb, even_odd ? "W* n\n" : "W n\n")
}

// ── Pila del Estado Gráfico (§8.4.2) ───────────────────────────

write_push_state :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "q\n")
}

write_pop_state :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "Q\n")
}

// ── Lógica del Motor (Abstracción de Alto Nivel) ───────────────

write_path_object :: proc(sb: ^strings.Builder, obj: ^Pdf_Page_Path_Object) {
	write_push_state(sb)
	write_line_width(sb, obj.line_width)

	if obj.stroked {
		write_stroke_rgb(sb, obj.stroke_color)
	}
	if obj.filled {
		write_fill_rgb(sb, obj.fill_color)
	}

	for cmd in obj.commands {
		switch cmd.kind {
		case .Move_To:
			// CORRECCIÓN: cmd.pts es [6]f32 (era [24][25]f32 — array 2D sin sentido).
			// Los índices 0 y 1 contienen x e y respectivamente.
			// Antes: write_move_to(sb, cmd.pts, cmd.pts[9]) → tipo y acceso incorrectos.
			write_move_to(sb, cmd.pts[0], cmd.pts[1])

		case .Line_To:
			// CORRECCIÓN: mismo problema que Move_To.
			// Antes: write_line_to(sb, cmd.pts, cmd.pts[9])
			write_line_to(sb, cmd.pts[0], cmd.pts[1])

		case .Curve_To:
			// CORRECCIÓN: Bézier cúbica tiene 3 puntos de control = 6 coords.
			// Antes: write_curve_to(sb, cmd.pts, cmd.pts[9], cmd.pts[9],
			//                       cmd.pts[9], cmd.pts[10], cmd.pts[10][9])
			// Todos los accesos eran erróneos (tipo 2D + índices fuera de límites).
			write_curve_to(
				sb,
				cmd.pts[0], cmd.pts[1], // Punto de control 1
				cmd.pts[2], cmd.pts[3], // Punto de control 2
				cmd.pts[4], cmd.pts[5], // Punto final
			)

		case .Close:
			write_close_path(sb)
		}
	}

	switch {
	case obj.filled && obj.stroked:
		write_fill_stroke(sb)
	case obj.filled:
		write_fill(sb)
	case obj.stroked:
		write_stroke(sb)
	}

	write_pop_state(sb)
}
