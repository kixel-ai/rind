import Rind.HashSpec
open rind.spec

/-!
Known-answer tests of `Rind.HashSpec`, whose transliteration of the standards
is trusted: FIPS 180-4's examples, RFC 4231's HMAC-SHA256 cases 2 and 6 (a key
longer than a block), RFC 5869's A.1, and RFC 6070's second PBKDF2 case.
-/

/-- The bytes `s` spells in hex. -/
def hex (s : String) : List Byte :=
  let d (c : Char) : Nat := if c.isDigit then c.toNat - '0'.toNat else c.toNat - 'a'.toNat + 10
  let rec go : List Char → List Byte
    | a :: b :: rest => BitVec.ofNat 8 (16 * d a + d b) :: go rest
    | _ => []
  go s.toList

/-- The bytes of `s`'s ASCII. -/
def ascii (s : String) : List Byte := s.toList.map fun c => BitVec.ofNat 8 c.toNat

def hmacSha256 := hmac sha256.hash 64

#guard sha256.hash (ascii "abc") ==
  hex "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
#guard sha256.hash (ascii "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
  hex "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
#guard sha1.hash (ascii "abc") == hex "a9993e364706816aba3e25717850c26c9cd0d89d"
#guard sha1.hash (ascii "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
  hex "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
#guard hmacSha256 (ascii "Jefe") (ascii "what do ya want for nothing?") ==
  hex "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
#guard hmacSha256 (List.replicate 131 0xaa) (ascii "Test Using Larger Than Block-Size Key - Hash Key First") ==
  hex "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
#guard hkdfExtract hmacSha256 (hex "000102030405060708090a0b0c") (List.replicate 22 0x0b) ==
  hex "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5"
#guard hkdfExpand hmacSha256 32
    (hex "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5")
    (hex "f0f1f2f3f4f5f6f7f8f9") 42 ==
  hex "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
#guard pbkdf2 (hmac sha1.hash 64) 20 (ascii "password") (ascii "salt") 2 20 ==
  hex "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957"
