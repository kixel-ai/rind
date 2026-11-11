"""OpenSSH's public key format: `<type> <base64 wire encoding> [comment]`."""

import base64
import binascii


def string(value):
    """An SSH `string`: a 32-bit length, then the bytes."""
    return len(value).to_bytes(4, "big") + value


def mpint(value):
    """An SSH `mpint` of a non-negative integer."""
    return string(value.to_bytes(value.bit_length() // 8 + 1, "big") if value else b"")


def encode_public(kind, body):
    """A public key line for `kind`, whose wire fields after the type are `body`."""
    return kind + b" " + base64.b64encode(string(kind) + body)


class Reader:
    """Reads SSH wire fields, raising `ValueError` past the end."""

    def __init__(self, data):
        self._data = data
        self._pos = 0

    def string(self):
        if len(self._data) - self._pos < 4:
            raise ValueError("Key is not in the proper format")
        length = int.from_bytes(self._data[self._pos : self._pos + 4], "big")
        self._pos += 4
        if len(self._data) - self._pos < length:
            raise ValueError("Key is not in the proper format")
        value = self._data[self._pos : self._pos + length]
        self._pos += length
        return value

    def mpint(self):
        value = self.string()
        if value and (value[0] & 0x80 or (len(value) > 1 and value[0] == 0 and not value[1] & 0x80)):
            raise ValueError("Key is not in the proper format")
        return int.from_bytes(value, "big")

    def done(self):
        if self._pos != len(self._data):
            raise ValueError("Key is not in the proper format")


def decode_public(data):
    """The type and wire fields of an OpenSSH public key line."""
    fields = bytes(data).strip().split(None, 2)
    if len(fields) < 2:
        raise ValueError("Key is not in the proper format")
    kind, encoded = fields[0], fields[1]
    try:
        wire = base64.b64decode(encoded, validate=True)
    except binascii.Error:
        raise ValueError("Key is not in the proper format") from None
    reader = Reader(wire)
    if reader.string() != kind:
        raise ValueError("Key is not in the proper format")
    return kind, reader
