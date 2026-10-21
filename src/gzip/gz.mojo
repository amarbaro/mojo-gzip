"""gzip, zlib and raw deflate for Mojo through the system libz.so.1, loaded at run time, so
`mojo run` and `mojo build` need no linker flag."""
from std.ffi import OwnedDLHandle, external_call

comptime _Z_STREAM = 112  # sizeof(z_stream) on 64-bit Linux
comptime _VERSION = "1.2.11"  # oldest ABI accepted; libz only checks the major digit
comptime Z_OK = 0
comptime Z_STREAM_END = 1
comptime Z_BUF_ERROR = -5


struct GzFile(Movable):
    """A .gz file streamed through gzopen: read() inflates chunk by chunk (plain files pass
    through unchanged, concatenated members are joined), write() deflates. close() reports a
    truncated or corrupt stream."""

    var z: OwnedDLHandle
    var f: Int
    var path: String
    var bad: Bool  # zlib flags a truncated or corrupt stream on the read that returns its last bytes

    def __init__(out self, path: String, mode: String = "rb") raises:
        """mode: "rb", or "wb"/"ab" with an optional level digit ("wb9")."""
        self.z = OwnedDLHandle("libz.so.1")
        self.path = path.copy()
        self.bad = False
        var p = path.copy()
        var m = mode.copy()
        self.f = self.z.call["gzopen", Int](p.as_c_string_span().ptr(), m.as_c_string_span().ptr())
        if self.f == 0:
            raise Error("gzip: cannot open ", path)
        _ = self.z.call["gzbuffer", Int32](self.f, UInt32(1 << 17))

    def read(mut self, mut buf: List[UInt8]) raises -> Int:
        """Fills buf (its length, not capacity) from the start; returns the bytes read, 0 at end."""
        if self.bad:
            raise Error("gzip: ", self.path, ": unexpected end of file")
        var n = Int(self.z.call["gzread", Int32](self.f, buf.unsafe_ptr(), UInt32(len(buf))))
        if n < 0:
            raise self._error()
        if self._code() != Z_OK:
            if n == 0:
                raise self._error()
            self.bad = True
        return n

    def write(mut self, data: Span[UInt8, _]) raises:
        if len(data) and Int(self.z.call["gzwrite", Int32](self.f, data.unsafe_ptr(), UInt32(len(data)))) != len(data):
            raise self._error()

    def close(mut self) raises:
        if self.f == 0:
            return
        var rc = Int(self.z.call["gzclose", Int32](self.f))
        self.f = 0
        if rc == Z_BUF_ERROR or self.bad:
            raise Error("gzip: ", self.path, ": unexpected end of file")
        if rc != Z_OK:
            raise Error("gzip: ", self.path, ": close failed (", rc, ")")

    def _code(self) -> Int:
        var code = Int32(0)
        _ = self.z.call["gzerror", Int](self.f, Pointer(to=code))
        return Int(code)

    def _error(self) -> Error:
        var code = Int32(0)
        var p = self.z.call["gzerror", Pointer[UInt8, ImmutAnyOrigin]](self.f, Pointer(to=code))
        var msg = StringSlice(unsafe_from_utf8=Span(unsafe_ptr=p, length=external_call["strlen", Int](p)))
        return Error("gzip: ", self.path, ": ", msg)

    def __deinit__(deinit self):
        if self.f != 0:
            _ = self.z.call["gzclose", Int32](self.f)


def read_all(path: String) raises -> List[UInt8]:
    """The whole inflated content of path (.gz or plain)."""
    var g = GzFile(path)
    var out = List[UInt8]()
    var buf = List[UInt8](length=1 << 17, fill=0)
    while True:
        var n = g.read(buf)
        if n == 0:
            break
        out.extend(Span(buf)[:n])
    g.close()
    return out^


def write_all(path: String, data: Span[UInt8, _], level: Int = 6) raises:
    var g = GzFile(path, "wb" + String(level))
    g.write(data)
    g.close()


def _set(mut s: List[UInt8], off: Int, v: Int):
    s.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[Int]()[] = v


def _get(s: List[UInt8], off: Int) -> Int:
    return s.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[Int]()[]


def _set32(mut s: List[UInt8], off: Int, v: Int):
    s.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[UInt32]()[] = UInt32(v)


def _get32(s: List[UInt8], off: Int) -> Int:
    return Int(s.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[UInt32]()[])


def compress(data: Span[UInt8, _], level: Int = 6, format: String = "gzip") raises -> List[UInt8]:
    """One deflate pass into an output sized by deflateBound. format: "gzip", "zlib" or "raw"."""
    var z = OwnedDLHandle("libz.so.1")
    var bits = 31 if format == "gzip" else (15 if format == "zlib" else -15)
    var s = List[UInt8](length=_Z_STREAM, fill=0)
    var v = String(_VERSION)
    if z.call["deflateInit2_", Int32](s.unsafe_ptr(), Int32(level), Int32(8), Int32(bits), Int32(8), Int32(0),
            v.as_c_string_span().ptr(), Int32(_Z_STREAM)) != Z_OK:
        raise Error("gzip: bad level ", level)
    var out = List[UInt8](length=z.call["deflateBound", Int](s.unsafe_ptr(), len(data)) + 18, fill=0)
    _set(s, 0, Int(data.unsafe_ptr()))
    _set32(s, 8, len(data))
    _set(s, 24, Int(out.unsafe_ptr()))
    _set32(s, 32, len(out))
    var rc = z.call["deflate", Int32](s.unsafe_ptr(), Int32(4))  # Z_FINISH
    var n = _get(s, 40)
    _ = z.call["deflateEnd", Int32](s.unsafe_ptr())
    if rc != Z_STREAM_END:
        raise Error("gzip: deflate failed (", rc, ")")
    out.resize(n, 0)
    return out^


def decompress(data: Span[UInt8, _], format: String = "auto") raises -> List[UInt8]:
    """Inflates gzip (every concatenated member), zlib ("auto" tells them apart) or "raw".
    Raises on corrupt, truncated or trailing non-gzip data."""
    var z = OwnedDLHandle("libz.so.1")
    var bits = 47 if format == "auto" else (31 if format == "gzip" else (15 if format == "zlib" else -15))
    var s = List[UInt8](length=_Z_STREAM, fill=0)
    var v = String(_VERSION)
    if z.call["inflateInit2_", Int32](s.unsafe_ptr(), Int32(bits), v.as_c_string_span().ptr(), Int32(_Z_STREAM)) != Z_OK:
        raise Error("gzip: inflateInit failed")
    var out = List[UInt8](length=max(len(data) * 4, 1 << 12), fill=0)
    _set(s, 0, Int(data.unsafe_ptr()))
    _set32(s, 8, len(data))
    var done = 0
    var err = ""
    while True:
        if done == len(out):
            out.resize(len(out) * 2, 0)
        _set(s, 24, Int(out.unsafe_ptr()) + done)
        _set32(s, 32, len(out) - done)
        var rc = Int(z.call["inflate", Int32](s.unsafe_ptr(), Int32(0)))
        done = len(out) - _get32(s, 32)
        var left = _get32(s, 8)
        if rc == Z_STREAM_END:
            if left == 0:
                break
            if bits == -15 or data[len(data) - left] != 0x1F:
                err = "trailing data"
                break
            _ = z.call["inflateReset", Int32](s.unsafe_ptr())  # next gzip member
        elif rc == Z_BUF_ERROR and done < len(out):
            err = "truncated input"
            break
        elif rc != Z_OK and rc != Z_BUF_ERROR:
            err = "corrupt input"
            break
    _ = z.call["inflateEnd", Int32](s.unsafe_ptr())
    if err:
        raise Error("gzip: ", err)
    out.resize(done, 0)
    return out^


def crc32(data: Span[UInt8, _], start: UInt32 = 0) -> UInt32:
    """CRC-32 as gzip, zip and PNG use it; equals Python zlib.crc32. Chain with start."""
    try:
        return UInt32(OwnedDLHandle("libz.so.1").call["crc32", UInt](UInt(start), data.unsafe_ptr(), UInt32(len(data))))
    except:
        return 0


def adler32(data: Span[UInt8, _], start: UInt32 = 1) -> UInt32:
    try:
        return UInt32(OwnedDLHandle("libz.so.1").call["adler32", UInt](UInt(start), data.unsafe_ptr(), UInt32(len(data))))
    except:
        return 0
