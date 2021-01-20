extern crate vergen;

fn main() {
    vergen::generate_cargo_keys(vergen::ConstantsFlags::all())
        .expect("Unable to generate cargo build env keys!");
}
