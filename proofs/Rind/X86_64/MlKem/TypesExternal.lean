module
public import Rind.X86_64.Types
@[expose] public section

/-! The types the x86_64 ML-KEM translation, `Rind.X86_64.MlKem.Funs`, leaves
opaque: the SHA-3 sponges, the entry guard, ASN.1's error, and
pyca/verified-garbage's ML-KEM-768 tokens, which it reaches as the target's
translation and `Rind.X86_64.TypesExternal` define them, in the namespace above
its own. -/
