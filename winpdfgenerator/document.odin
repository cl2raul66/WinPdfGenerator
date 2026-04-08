#+private
package winpdfgenerator

import "core:time"

// generate_file_id produce un identificador de 16 bytes para /ID del XRef Stream.
// En producción sustituir por core:crypto/md5 del contenido del documento.
generate_file_id :: proc(seed: string) -> [16]byte {
	h: [16]byte
	now := time.now()
	ns := time.time_to_unix_nano(now)
	for i in 0..<16 {
		seed_byte := seed[i % max(len(seed), 1)]
		time_byte := byte(ns >> uint(i * 8))
		h[i] = seed_byte ~ time_byte ~ byte(i * 0x1B)
	}
	return h
}
