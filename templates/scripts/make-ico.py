#!/usr/bin/env python3
# kiro-template v2.0.0
"""Pack PNG files into a multi-size .ico (PNG-in-ICO entries, stdlib only).

Usage: scripts/make-ico.py OUT.ico IN-16.png IN-32.png IN-48.png
"""
import struct
import sys

PNG_SIG = b"\x89PNG\r\n\x1a\n"


def png_size(data: bytes) -> tuple[int, int]:
    if data[:8] != PNG_SIG or data[12:16] != b"IHDR":
        raise ValueError("not a PNG file")
    return struct.unpack(">II", data[16:24])


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    out, inputs = argv[1], argv[2:]
    images = []
    for path in inputs:
        with open(path, "rb") as f:
            data = f.read()
        w, h = png_size(data)
        if w > 256 or h > 256:
            raise ValueError(f"{path}: {w}x{h} is larger than 256x256")
        images.append((w, h, data))

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    entries = b""
    for w, h, data in images:
        # width/height 0 means 256; 0 colours, 0 reserved, 1 plane, 32 bpp, size, offset
        entries += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    with open(out, "wb") as f:
        f.write(header + entries + b"".join(d for _, _, d in images))
    print(f"wrote {out} ({', '.join(f'{w}x{h}' for w, h, _ in images)})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
