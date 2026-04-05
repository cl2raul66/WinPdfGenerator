#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Destinos (ISO 32000-2 §12.3.2) ─────────────────────────────

Destination_Kind :: enum {
	XYZ,  // [page /XYZ left top zoom]   (§Table 149)
	Fit,  // [page /Fit]
	FitH, // [page /FitH top]
	FitV, // [page /FitV left]
	FitR, // [page /FitR left bottom right top] — 4 coordenadas
}

Pdf_Destination :: struct {
	page:   Pdf_Ref,
	kind:   Destination_Kind,
	// CORRECCIÓN: Era [3]f32. FitR requiere 4 coordenadas (left, bottom, right, top).
	// XYZ también usa 3 (left, top, zoom), por lo que [4]f32 cubre todos los casos.
	params: [4]f32,
}

// ── Acciones (ISO 32000-2 §12.6) ───────────────────────────────

Action_Kind :: enum {
	GoTo,   // Ir a destino en el mismo documento
	GoToR,  // Ir a destino en documento remoto
	URI,    // Enlace a Internet
	Launch, // Ejecutar aplicación o abrir archivo
	Named,  // Acciones predefinidas (/NextPage, /PrevPage, etc.)
}

Pdf_Action :: struct {
	kind: Action_Kind,
	data: union {
		Pdf_Destination,
		string,   // URI (url) o Launch (ruta)
		Pdf_Ref,  // GoToR (referencia al archivo externo)
	},
}

// ── Anotaciones (ISO 32000-2 §12.5) ───────────────────────────

Annotation_Link :: struct {
	dest:   Maybe(Pdf_Destination),
	action: Maybe(Pdf_Action),
	rect:   Rect,
}

Annotation_Text :: struct {
	contents: string,
	open:     bool,
	name:     Pdf_Name, // Icono: /Comment, /Key, /Note, etc.
}

// CORRECCIÓN: Annotation estaba definido dos veces en el paquete:
// - En types.odin como struct{ data: union{Annotation_Highlight} }
// - Aquí como union{ Annotation_Link, Annotation_Text }
// Se unifican en un único union que cubre todos los tipos.
// La definición de types.odin queda eliminada.
Annotation :: union {
	Annotation_Link,
	Annotation_Text,
	Annotation_Highlight, // Tipo definido en types.odin
}

// ── Esquema / Bookmarks (ISO 32000-2 §12.3.3) ─────────────────

Pdf_Outline_Item :: struct {
	title:    string,
	dest:     Maybe(Pdf_Destination),
	action:   Maybe(Pdf_Action),
	color:    Maybe(Color_RGB),
	italic:   bool,
	bold:     bool,
	children: [dynamic]^Pdf_Outline_Item,
	opened:   bool,
}

// ── Lógica de Conversión ──────────────────────────────────────

destination_to_pdf :: proc(d: Pdf_Destination) -> [dynamic]Pdf_Object {
	arr := make([dynamic]Pdf_Object)
	append(&arr, d.page)

	switch d.kind {
	case .XYZ:
		append(&arr, Pdf_Name("/XYZ"))
		// CORRECCIÓN: Acceso a índices 0, 1, 2 del array [4]f32.
		// Antes: d.params[4], d.params[5] → fuera de límites de [3]f32.
		append(&arr, d.params[0]) // left
		append(&arr, d.params[1]) // top
		append(&arr, d.params[2]) // zoom

	case .Fit:
		append(&arr, Pdf_Name("/Fit"))

	case .FitH:
		append(&arr, Pdf_Name("/FitH"))
		// CORRECCIÓN: Antes era append(&arr, d.params) que añadía el array
		// completo como un único elemento. Debe ser el valor escalar params[0].
		append(&arr, d.params[0]) // top

	case .FitV:
		append(&arr, Pdf_Name("/FitV"))
		// CORRECCIÓN: mismo que FitH.
		append(&arr, d.params[0]) // left

	case .FitR:
		append(&arr, Pdf_Name("/FitR"))
		// CORRECCIÓN: Antes: d.params[4], d.params[5], d.params[6] →
		// fuera de límites de [3]f32. FitR usa 4 coords sobre [4]f32.
		append(&arr, d.params[0]) // left
		append(&arr, d.params[1]) // bottom
		append(&arr, d.params[2]) // right
		append(&arr, d.params[3]) // top
	}
	return arr
}

action_to_pdf :: proc(a: Pdf_Action) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Type"] = Pdf_Name("/Action")

	switch v in a.data {
	case Pdf_Destination:
		d["/S"] = Pdf_Name("/GoTo")
		d["/D"] = destination_to_pdf(v)

	case string:
		if a.kind == .URI {
			d["/S"]   = Pdf_Name("/URI")
			d["/URI"] = v
		} else if a.kind == .Launch {
			d["/S"] = Pdf_Name("/Launch")
			f_dict := make(Pdf_Dict)
			f_dict["/Type"] = Pdf_Name("/Filespec")
			f_dict["/F"]    = v
			d["/F"] = f_dict
		}

	case Pdf_Ref:
		if a.kind == .GoToR {
			d["/S"] = Pdf_Name("/GoToR")
			d["/F"] = v
		}
	}
	return d
}

outline_destroy :: proc(item: ^Pdf_Outline_Item) {
	if item == nil do return
	for child in item.children {
		outline_destroy(child)
	}
	delete(item.children)
	free(item)
}
