import io
import re

from driver import (
    Architecture_aarch64,
    Architecture_amd64,
    RustDriver,
    generated,
)
from parse import parse_file

S2N = "../../thirdparty/s2n-bignum"


def expand_gas_macros(path):
    """
    Expands the assembler's `.macro` definitions, which parse_file does not
    understand, returning the source with each invocation replaced by its body.

    This handles what s2n-bignum's ML-DSA kernels use: named parameters with
    optional defaults, `\\name` substitution, nested invocations, and
    `.if`/`.else`/`.endif` on a constant expression.
    """
    with open(path) as f:
        text = f.read()

    # parse_file reads `//` comments, not `/* */` ones.
    text = re.sub(
        r"/\*(.*?)\*/",
        lambda m: "\n".join(
            "// " + c.strip().lstrip("*").strip() for c in m.group(1).splitlines()
        ),
        text,
        flags=re.DOTALL,
    )
    lines = text.splitlines(keepends=True)

    macros = {}
    body = []
    current = None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(".macro"):
            words = stripped[len(".macro") :].strip()
            name, _, params = words.partition(" ")
            parameters = []
            for p in re.split(r"[\s,]+", params.strip()):
                if p:
                    pname, _, default = p.partition("=")
                    parameters.append((pname, default or None))
            current = (name, parameters, [])
        elif stripped == ".endm":
            macros[current[0]] = current
            current = None
        elif current is not None:
            current[2].append(line)
        else:
            body.append(line)

    def expand(lines, depth=0):
        assert depth < 16, "macro recursion"
        out = []
        for line in lines:
            words = line.split(None, 1)
            if words and words[0] in macros:
                name, parameters, mbody = macros[words[0]]
                args = [a for a in re.split(r"[\s,]+", words[1].strip())] if len(words) > 1 else []
                assert len(args) <= len(parameters), line
                values = {}
                for i, (pname, default) in enumerate(parameters):
                    value = args[i] if i < len(args) else default
                    assert value is not None, "missing %s in %r" % (pname, line)
                    values[pname] = value
                substituted = [
                    re.sub(r"\\(\w+)", lambda m: values[m.group(1)], b) for b in mbody
                ]
                out.extend(expand(conditionals(substituted), depth + 1))
            else:
                out.append(line)
        return out

    def conditionals(lines):
        out = []
        keep = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith(".if "):
                keep.append(int(eval(stripped[4:], {"__builtins__": {}})) != 0)
            elif stripped == ".else":
                keep[-1] = not keep[-1]
            elif stripped == ".endif":
                keep.pop()
            elif all(keep):
                out.append(line)
        assert not keep, "unterminated .if"
        return out

    result = io.StringIO("".join(expand(body)))
    result.name = path
    return result


def fix_docs(path):
    """
    Fixes the Markdown in `path`'s doc comments that rustdoc would misread:
    the continuation lines of a numbered item, whose indentation the driver
    strips, are indented under it again, and a leading `>` is escaped.
    """
    with open(path) as f:
        lines = f.read().splitlines(keepends=True)
    indent = None
    for n, line in enumerate(lines):
        if not line.startswith("///"):
            indent = None
            continue
        text = line[3:].rstrip("\n").removeprefix(" ")
        stripped = text.lstrip()
        item = re.match(r"\d+\. ", stripped)
        if item:
            indent = len(text) - len(stripped) + item.end()
        elif not stripped:
            indent = None
        elif indent is not None:
            text = " " * indent + stripped
        if text.startswith(">"):
            text = "\\" + text
        lines[n] = ("/// " + text).rstrip() + "\n"
    with open(path, "w") as f:
        f.write("".join(lines))


def aligned(*names):
    return ["(%s as usize).is_multiple_of(32)" % n for n in names]


def emit(arch, source, output, symbol, rust_decl, parameter_map, **kwargs):
    architecture = Architecture_amd64 if arch == "x86_64" else Architecture_aarch64
    directory = "x86" if arch == "x86_64" else "arm"
    with (
        expand_gas_macros("%s/%s/mldsa/%s.S" % (S2N, directory, source)) as input,
        generated("../../rind/src/low/%s/%s.rs" % (arch, output)) as out,
    ):
        d = RustDriver(out, architecture)
        d.emit_rust_function(
            symbol,
            parameter_map=parameter_map,
            rust_decl=rust_decl,
            **kwargs,
        )
        parse_file(input, d)
    fix_docs("../../rind/src/low/%s/%s.rs" % (arch, output))


def x86_64():
    for name in ("ntt", "intt"):
        emit(
            "x86_64",
            "mldsa_" + name,
            "mldsa_" + name,
            "mldsa_" + name,
            "fn mldsa_%s(a: &mut [i32; 256], qdata: &[i32; 624])" % name,
            [
                ("inout", "a.as_mut_ptr() => _"),
                ("inout", "qdata.as_ptr() => _"),
            ],
            assertions=aligned("a.as_mut_ptr()", "qdata.as_ptr()"),
        )

    for name in ("nttunpack", "caddq", "reduce"):
        emit(
            "x86_64",
            "mldsa_" + name,
            "mldsa_" + name,
            "mldsa_" + name,
            "fn mldsa_%s(a: &mut [i32; 256])" % name,
            [("inout", "a.as_mut_ptr() => _")],
            assertions=aligned("a.as_mut_ptr()"),
        )

    emit(
        "x86_64",
        "mldsa_pointwise",
        "mldsa_pointwise",
        "mldsa_pointwise_x86",
        "fn mldsa_pointwise(c: &mut [i32; 256], a: &[i32; 256], b: &[i32; 256], qdata: &[i32; 16])",
        [
            ("inout", "c.as_mut_ptr() => _"),
            ("inout", "a.as_ptr() => _"),
            ("inout", "b.as_ptr() => _"),
            ("inout", "qdata.as_ptr() => _"),
        ],
        assertions=aligned(
            "c.as_mut_ptr()", "a.as_ptr()", "b.as_ptr()", "qdata.as_ptr()"
        ),
    )

    for l in (4, 5, 7):
        emit(
            "x86_64",
            "mldsa_pointwise_acc_l%d" % l,
            "mldsa_pointwise_acc_l%d" % l,
            "mldsa_pointwise_acc_l%d_x86" % l,
            "fn mldsa_pointwise_acc_l%d(c: &mut [i32; 256], a: &[[i32; 256]; %d], b: &[[i32; 256]; %d], qdata: &[i32; 624])"
            % (l, l, l),
            [
                ("inout", "c.as_mut_ptr() => _"),
                ("inout", "a.as_ptr() => _"),
                ("inout", "b.as_ptr() => _"),
                ("inout", "qdata.as_ptr() => _"),
            ],
            assertions=aligned(
                "c.as_mut_ptr()", "a.as_ptr()", "b.as_ptr()", "qdata.as_ptr()"
            ),
        )

    emit(
        "x86_64",
        "mldsa_chknorm",
        "mldsa_chknorm",
        "mldsa_chknorm",
        "fn mldsa_chknorm(a: &[i32; 256], bound: u64) -> u64",
        [
            ("inout", "a.as_ptr() => _"),
            ("inout", "bound => _"),
        ],
        return_value=("u64", "ret", "ret"),
        return_map=("out", "ret"),
        assertions=aligned("a.as_ptr()"),
    )

    for g in (32, 88):
        emit(
            "x86_64",
            "mldsa_decompose_%d" % g,
            "mldsa_decompose_%d" % g,
            "mldsa_decompose_%d" % g,
            "fn mldsa_decompose_%d(a1: &mut [i32; 256], a0: &mut [i32; 256])" % g,
            [
                ("inout", "a1.as_mut_ptr() => _"),
                ("inout", "a0.as_mut_ptr() => _"),
            ],
            assertions=aligned("a1.as_mut_ptr()", "a0.as_mut_ptr()"),
        )
        emit(
            "x86_64",
            "mldsa_poly_use_hint_%d" % g,
            "mldsa_poly_use_hint_%d" % g,
            "mldsa_poly_use_hint_%d" % g,
            "fn mldsa_poly_use_hint_%d(a: &mut [i32; 256], h: &[i32; 256])" % g,
            [
                ("inout", "a.as_mut_ptr() => _"),
                ("inout", "h.as_ptr() => _"),
            ],
            assertions=aligned("a.as_mut_ptr()", "h.as_ptr()"),
        )

    for bits, length in ((17, 576), (19, 640)):
        emit(
            "x86_64",
            "mldsa_polyz_unpack_%d" % bits,
            "mldsa_polyz_unpack_%d" % bits,
            "mldsa_polyz_unpack_%d_x86" % bits,
            "fn mldsa_polyz_unpack_%d(r: &mut [i32; 256], b: &[u8; %d])"
            % (bits, length),
            [
                ("inout", "r.as_mut_ptr() => _"),
                ("inout", "b.as_ptr() => _"),
            ],
            assertions=aligned("r.as_mut_ptr()"),
        )

    emit(
        "x86_64",
        "mldsa_rej_uniform_VARIABLE_TIME",
        "mldsa_rej_uniform_vartime",
        "mldsa_rej_uniform_VARIABLE_TIME_x86",
        "fn mldsa_rej_uniform_vartime(r: &mut [i32; 256], buf: &[u8; 840], table: &[u8; 2048]) -> u64",
        [
            ("inout", "r.as_mut_ptr() => _"),
            ("inout", "buf.as_ptr() => _"),
            ("inout", "table.as_ptr() => _"),
        ],
        return_value=("u64", "ret", "ret"),
        return_map=("out", "ret"),
        assertions=aligned("r.as_mut_ptr()"),
    )

    for eta, length in ((2, 136), (4, 272)):
        emit(
            "x86_64",
            "mldsa_rej_uniform_eta%d_VARIABLE_TIME" % eta,
            "mldsa_rej_uniform_eta%d_vartime" % eta,
            "mldsa_rej_uniform_eta%d_VARIABLE_TIME_x86" % eta,
            "fn mldsa_rej_uniform_eta%d_vartime(r: &mut [i32; 256], buf: &[u8; %d], table: &[u8; 2048]) -> u64"
            % (eta, length),
            [
                ("inout", "r.as_mut_ptr() => _"),
                ("inout", "buf.as_ptr() => _"),
                ("inout", "table.as_ptr() => _"),
            ],
            return_value=("u64", "ret", "ret"),
            return_map=("out", "ret"),
            assertions=aligned("r.as_mut_ptr()"),
        )


def aarch64():
    emit(
        "aarch64",
        "mldsa_ntt",
        "mldsa_ntt",
        "mldsa_ntt_arm",
        "fn mldsa_ntt(a: &mut [i32; 256], z_012345: &[i32; 144], z_67: &[i32; 384])",
        [
            ("inout", "a.as_mut_ptr() => _"),
            ("inout", "z_012345.as_ptr() => _"),
            ("inout", "z_67.as_ptr() => _"),
        ],
    )

    emit(
        "aarch64",
        "mldsa_intt",
        "mldsa_intt",
        "mldsa_intt_arm",
        "fn mldsa_intt(a: &mut [i32; 256], z_78: &[i32; 384], z_123456: &[i32; 160])",
        [
            ("inout", "a.as_mut_ptr() => _"),
            ("inout", "z_78.as_ptr() => _"),
            ("inout", "z_123456.as_ptr() => _"),
        ],
    )

    emit(
        "aarch64",
        "mldsa_caddq",
        "mldsa_caddq",
        "mldsa_caddq",
        "fn mldsa_caddq(a: &mut [i32; 256])",
        [("inout", "a.as_mut_ptr() => _")],
    )

    emit(
        "aarch64",
        "mldsa_pointwise",
        "mldsa_pointwise",
        "mldsa_pointwise",
        "fn mldsa_pointwise(c: &mut [i32; 256], a: &[i32; 256], b: &[i32; 256])",
        [
            ("inout", "c.as_mut_ptr() => _"),
            ("inout", "a.as_ptr() => _"),
            ("inout", "b.as_ptr() => _"),
        ],
    )

    for l in (4, 5, 7):
        emit(
            "aarch64",
            "mldsa_pointwise_acc_l%d" % l,
            "mldsa_pointwise_acc_l%d" % l,
            "mldsa_pointwise_acc_l%d" % l,
            "fn mldsa_pointwise_acc_l%d(c: &mut [i32; 256], a: &[[i32; 256]; %d], b: &[[i32; 256]; %d])"
            % (l, l, l),
            [
                ("inout", "c.as_mut_ptr() => _"),
                ("inout", "a.as_ptr() => _"),
                ("inout", "b.as_ptr() => _"),
            ],
        )

    emit(
        "aarch64",
        "mldsa_chknorm",
        "mldsa_chknorm",
        "mldsa_chknorm",
        "fn mldsa_chknorm(a: &[i32; 256], bound: u64) -> u64",
        [
            ("inout", "a.as_ptr() => ret"),
            ("inout", "bound => _"),
        ],
        return_value=("u64", "ret", "ret"),
    )

    for g in (32, 88):
        emit(
            "aarch64",
            "mldsa_decompose_%d" % g,
            "mldsa_decompose_%d" % g,
            "mldsa_decompose_%d" % g,
            "fn mldsa_decompose_%d(a1: &mut [i32; 256], a0: &mut [i32; 256])" % g,
            [
                ("inout", "a1.as_mut_ptr() => _"),
                ("inout", "a0.as_mut_ptr() => _"),
            ],
        )
        emit(
            "aarch64",
            "mldsa_poly_use_hint_%d" % g,
            "mldsa_poly_use_hint_%d" % g,
            "mldsa_poly_use_hint_%d" % g,
            "fn mldsa_poly_use_hint_%d(b: &mut [i32; 256], a: &[i32; 256], h: &[i32; 256])"
            % g,
            [
                ("inout", "b.as_mut_ptr() => _"),
                ("inout", "a.as_ptr() => _"),
                ("inout", "h.as_ptr() => _"),
            ],
        )

    for bits, length in ((17, 576), (19, 640)):
        emit(
            "aarch64",
            "mldsa_polyz_unpack_%d" % bits,
            "mldsa_polyz_unpack_%d" % bits,
            "mldsa_polyz_unpack_%d_arm" % bits,
            "fn mldsa_polyz_unpack_%d(r: &mut [i32; 256], b: &[u8; %d], t: &[u8; 64])"
            % (bits, length),
            [
                ("inout", "r.as_mut_ptr() => _"),
                ("inout", "b.as_ptr() => _"),
                ("inout", "t.as_ptr() => _"),
            ],
        )

    emit(
        "aarch64",
        "mldsa_rej_uniform_VARIABLE_TIME",
        "mldsa_rej_uniform_vartime",
        "mldsa_rej_uniform_VARIABLE_TIME",
        "fn mldsa_rej_uniform_vartime(r: &mut [i32; 256], buf: &[u8], table: &[u8; 256]) -> u64",
        [
            ("inout", "r.as_mut_ptr() => ret"),
            ("inout", "buf.as_ptr() => _"),
            ("inout", "buf.len() => _"),
            ("inout", "table.as_ptr() => _"),
        ],
        return_value=("u64", "ret", "ret"),
        assertions=["buf.len().is_multiple_of(24)"],
    )

    for eta, length in ((2, 136), (4, 272)):
        emit(
            "aarch64",
            "mldsa_rej_uniform_eta%d_VARIABLE_TIME" % eta,
            "mldsa_rej_uniform_eta%d_vartime" % eta,
            "mldsa_rej_uniform_eta%d_VARIABLE_TIME" % eta,
            "fn mldsa_rej_uniform_eta%d_vartime(r: &mut [i32; 256], buf: &[u8; %d], table: &[i8; 4096]) -> u64"
            % (eta, length),
            [
                ("inout", "r.as_mut_ptr() => ret"),
                ("inout", "buf.as_ptr() => _"),
                ("inout", "buf.len() => _"),
                ("inout", "table.as_ptr() => _"),
            ],
            return_value=("u64", "ret", "ret"),
        )


if __name__ == "__main__":
    x86_64()
    aarch64()
