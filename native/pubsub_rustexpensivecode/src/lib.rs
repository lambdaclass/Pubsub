use rustler::types::atom::{ok};
use rustler::{Encoder, Env, NifResult, Term};

use std::thread;

#[rustler::nif(schedule = "DirtyCpu")]
fn do_work(
    env: Env
) -> NifResult<Term> {
    let thread = thread::Builder::new()
        .name("do_some_work".to_string())
        .stack_size(1024 * 1024 * 8)
        .spawn(
            move || -> Result<(), String> {
                // I think Box::new first allocates that array of bytes in the stack and that's the problem
                Box::new([0u8; 1_000 * 1_000 * 10]);

                Ok(())
            },
        )
        .unwrap();

    let _ = thread.join();
    return Ok((ok()).encode(env));
}

rustler::init!("Elixir.Pubsub.RustExpensiveCode", [do_work]);
