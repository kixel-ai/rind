//! Temporary: times aarch64 `cipher::ChaCha20`'s paths at every length,
//! built with `--cfg rind_sweep`. Prints `len,path,ns` per path.

#![allow(unexpected_cfgs)]

#[cfg(not(all(rind_sweep, target_arch = "aarch64")))]
fn main() {}

#[cfg(all(rind_sweep, target_arch = "aarch64"))]
fn main() {
    use std::hint::black_box;
    use std::time::Instant;

    let paths: Vec<u8> = std::env::args()
        .nth(1)
        .unwrap_or("1,2,3".into())
        .split(',')
        .map(|p| p.parse().unwrap())
        .collect();
    let rounds: usize = std::env::var("ROUNDS").map_or(15, |r| r.parse().unwrap());
    let key = rind::cipher::ChaCha20::new(&[7; 32]);
    let nonce = [9u8; 12];
    let lens: Vec<usize> = (1..=2112).chain([4096, 16384]).collect();
    let mut buf = vec![0u8; 16384];
    println!("len,{}", paths.iter().map(|p| format!("p{p}")).collect::<Vec<_>>().join(","));
    for &len in &lens {
        let iters = (400_000 / (len + 128)).max(4);
        let mut best = vec![f64::MAX; paths.len()];
        for _ in 0..rounds {
            for (i, &p) in paths.iter().enumerate() {
                rind::cipher::__sweep(p);
                let start = Instant::now();
                for _ in 0..iters {
                    key.apply_keystream(black_box(&nonce), 0, black_box(&mut buf[..len]))
                        .unwrap();
                }
                let ns = start.elapsed().as_nanos() as f64 / iters as f64;
                best[i] = best[i].min(ns);
            }
        }
        println!(
            "{len},{}",
            best.iter().map(|b| format!("{b:.1}")).collect::<Vec<_>>().join(",")
        );
    }
}
